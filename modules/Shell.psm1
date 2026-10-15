# Integração com o shell do Windows: atalhos (.lnk), pastas especiais e a identidade do WinForge na barra de tarefas
# (AppUserModelID). É a única parte do projeto que usa COM e a API do shell; Launcher.psm1 decide o que criar e onde.
# Tudo aqui é opcional: se o Windows recusar, o WinForge continua funcionando (só perde o acabamento).

# C# compatível com o compilador do Windows PowerShell 5.1 (C# 5): sem interpolação de strings, sem "?." e afins.
$script:ShellInteropSource = @'
using System;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
using System.Threading;

namespace WinForge
{
    public static class ShellIdentity
    {
        // System.AppUserModel.* (propkey.h): mesmo GUID, números 2 a 5.
        private static readonly Guid AppUserModelFormat = new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3");
        private const uint RelaunchCommandId = 2;
        private const uint RelaunchIconResourceId = 3;
        private const uint RelaunchDisplayNameId = 4;
        private const uint AppIdId = 5;
        private const int StgmReadWrite = 2;

        [StructLayout(LayoutKind.Sequential, Pack = 4)]
        private struct PropertyKey
        {
            public Guid FormatId;
            public uint PropertyId;
        }

        // PROPVARIANT: 16 bytes em x86 e 24 em x64 (o ponteiro muda de tamanho e o alinhamento acompanha).
        [StructLayout(LayoutKind.Sequential)]
        private struct PropVariant
        {
            public ushort ValueType;
            public ushort Reserved1;
            public ushort Reserved2;
            public ushort Reserved3;
            public IntPtr Pointer;
            public int Extra;
        }

        [ComImport]
        [Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99")]
        [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        private interface IPropertyStore
        {
            [PreserveSig] int GetCount(out uint count);
            [PreserveSig] int GetAt(uint index, out PropertyKey key);
            [PreserveSig] int GetValue(ref PropertyKey key, out PropVariant value);
            [PreserveSig] int SetValue(ref PropertyKey key, ref PropVariant value);
            [PreserveSig] int Commit();
        }

        [ComImport]
        [Guid("00021401-0000-0000-C000-000000000046")]
        private class ShellLinkObject
        {
        }

        [DllImport("shell32.dll", CharSet = CharSet.Unicode, ExactSpelling = true)]
        private static extern int SetCurrentProcessExplicitAppUserModelID([MarshalAs(UnmanagedType.LPWStr)] string appId);

        [DllImport("shell32.dll", ExactSpelling = true)]
        private static extern int SHGetPropertyStoreForWindow(IntPtr handle, ref Guid riid, [MarshalAs(UnmanagedType.Interface)] out IPropertyStore store);

        [DllImport("propsys.dll", CharSet = CharSet.Unicode, ExactSpelling = true)]
        private static extern int InitPropVariantFromString([MarshalAs(UnmanagedType.LPWStr)] string value, out PropVariant variant);

        [DllImport("ole32.dll", ExactSpelling = true)]
        private static extern int PropVariantClear(ref PropVariant variant);

        // Devolve 0 (S_OK) quando o Windows aceitou.
        public static int SetProcessAppId(string appId)
        {
            return SetCurrentProcessExplicitAppUserModelID(appId);
        }

        private static void SetString(IPropertyStore store, uint propertyId, string value)
        {
            PropertyKey key = new PropertyKey();
            key.FormatId = AppUserModelFormat;
            key.PropertyId = propertyId;

            PropVariant variant;
            Marshal.ThrowExceptionForHR(InitPropVariantFromString(value, out variant));

            try
            {
                Marshal.ThrowExceptionForHR(store.SetValue(ref key, ref variant));
            }
            finally
            {
                PropVariantClear(ref variant);
            }
        }

        // Faz o botão da barra de tarefas e o "Fixar" da janela abrirem o WinForge (nome, ícone e comando próprios),
        // em vez do PowerShell que hospeda a janela. Devolve "" se deu certo ou a mensagem do erro.
        public static string SetWindowRelaunch(IntPtr handle, string appId, string command, string iconResource, string displayName)
        {
            try
            {
                Guid storeId = new Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99");
                IPropertyStore store;
                Marshal.ThrowExceptionForHR(SHGetPropertyStoreForWindow(handle, ref storeId, out store));

                try
                {
                    SetString(store, AppIdId, appId);
                    SetString(store, RelaunchCommandId, command);
                    SetString(store, RelaunchDisplayNameId, displayName);

                    if (!string.IsNullOrEmpty(iconResource))
                    {
                        SetString(store, RelaunchIconResourceId, iconResource);
                    }

                    Marshal.ThrowExceptionForHR(store.Commit());
                }
                finally
                {
                    Marshal.ReleaseComObject(store);
                }

                return "";
            }
            catch (Exception ex)
            {
                return ex.Message;
            }
        }

        private static void SetShortcutAppIdCore(string shortcutPath, string appId)
        {
            object link = new ShellLinkObject();

            try
            {
                IPersistFile file = (IPersistFile)link;
                file.Load(shortcutPath, StgmReadWrite);

                SetString((IPropertyStore)link, AppIdId, appId);
                Marshal.ThrowExceptionForHR(((IPropertyStore)link).Commit());

                file.Save(shortcutPath, true);
            }
            finally
            {
                Marshal.ReleaseComObject(link);
            }
        }

        // Grava o AppUserModelID dentro do .lnk, para que o atalho (e o "Fixar") se una ao botão da janela.
        // Roda em uma thread própria em modo STA, que é o que o objeto de atalho do shell espera.
        // Devolve "" se deu certo ou a mensagem do erro.
        public static string SetShortcutAppId(string shortcutPath, string appId)
        {
            string failure = "";

            Thread worker = new Thread(delegate ()
            {
                try
                {
                    SetShortcutAppIdCore(shortcutPath, appId);
                }
                catch (Exception ex)
                {
                    failure = ex.Message;
                }
            });

            worker.SetApartmentState(ApartmentState.STA);
            worker.Start();
            worker.Join();

            return failure;
        }
    }
}
'@


function Initialize-WinForgeShellInterop {
    # Compila a ponte com o shell uma vez por processo. Devolve $false se não foi possível.
    if ("WinForge.ShellIdentity" -as [type]) {
        return $true
    }

    try {
        Add-Type -TypeDefinition $script:ShellInteropSource -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}


function Get-WinForgeSpecialFolder {
    # Pasta do perfil de quem está executando (respeita OneDrive e nomes em outros idiomas). Vazio se não existir.
    param (
        [Parameter(Mandatory)]
        [ValidateSet("Desktop", "StartMenu")]
        [string]$Name
    )

    $special = switch ($Name) {
        "Desktop"   { "DesktopDirectory" }
        "StartMenu" { "Programs" }
    }

    try {
        return [string][Environment]::GetFolderPath($special)
    }
    catch {
        return ""
    }
}


function Set-WinForgeProcessAppId {
    # Dá ao processo um identificador próprio na barra de tarefas. Sem isso o Windows agrupa a janela com os demais
    # PowerShell e mostra o ícone do PowerShell. Devolve $true se o Windows aceitou.
    param (
        [Parameter(Mandatory)]
        [string]$AppId
    )

    if (-not (Initialize-WinForgeShellInterop)) {
        return $false
    }

    try {
        return ([WinForge.ShellIdentity]::SetProcessAppId($AppId) -eq 0)
    }
    catch {
        return $false
    }
}


function Set-WinForgeWindowRelaunch {
    # Associa à janela o comando, o nome e o ícone do WinForge (usados pelo "Fixar na barra de tarefas").
    # A janela precisa já ter um identificador (Handle válido). Devolve $true se o Windows aceitou.
    param (
        [Parameter(Mandatory)]
        [IntPtr]$Handle,

        [Parameter(Mandatory)]
        [string]$AppId,

        [Parameter(Mandatory)]
        [string]$Command,

        [string]$IconResource = "",

        [string]$DisplayName = "WinForge"
    )

    if (-not (Initialize-WinForgeShellInterop)) {
        return $false
    }

    try {
        return [string]::IsNullOrEmpty([WinForge.ShellIdentity]::SetWindowRelaunch($Handle, $AppId, $Command, $IconResource, $DisplayName))
    }
    catch {
        return $false
    }
}


function Save-WinForgeShortcutFile {
    <#
    Grava um atalho (.lnk). Um erro ao gravar (pasta sem permissão, por exemplo) sobe como exceção; já a gravação do
    identificador da barra de tarefas é opcional e só resulta em AppIdSet = $false.
    #>
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Target,

        [string]$Arguments = "",

        [string]$WorkingDirectory = "",

        [string]$IconLocation = "",

        [string]$Description = "",

        [string]$AppId = ""
    )

    $shell = $null
    $link = $null

    try {
        $shell = New-Object -ComObject WScript.Shell
        $link = $shell.CreateShortcut($Path)
        $link.TargetPath = $Target
        $link.Arguments = $Arguments

        if (-not [string]::IsNullOrEmpty($WorkingDirectory)) { $link.WorkingDirectory = $WorkingDirectory }
        if (-not [string]::IsNullOrEmpty($IconLocation)) { $link.IconLocation = $IconLocation }

        $link.Description = $Description
        $link.WindowStyle = 7   # minimizada: o console do PowerShell nem chega a aparecer
        $link.Save()
    }
    finally {
        foreach ($com in @($link, $shell)) {
            if ($null -ne $com) { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($com) }
        }
    }

    $appIdSet = $false

    if (-not [string]::IsNullOrEmpty($AppId) -and (Initialize-WinForgeShellInterop)) {
        try {
            $appIdSet = [string]::IsNullOrEmpty([WinForge.ShellIdentity]::SetShortcutAppId($Path, $AppId))
        }
        catch {
            $appIdSet = $false
        }
    }

    return [PSCustomObject]@{
        Path     = $Path
        AppIdSet = $appIdSet
    }
}


Export-ModuleMember -Function *
