param(
    [string]$Executable = (Join-Path $PSScriptRoot '../bin/Release/net48/twenty.exe')
)

# Run with Windows PowerShell (-STA): the app targets .NET Framework 4.8.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework
$assembly = [Reflection.Assembly]::LoadFrom((Resolve-Path $Executable))
[System.Windows.Application]::ResourceAssembly = $assembly
$app = New-Object twenty.App
$app.InitializeComponent()
$window = New-Object twenty.MainWindow
$icon = $window.FindName('MyNotifyIcon')
$flags = [Reflection.BindingFlags]'Instance,NonPublic,Public'

try {
    if ($icon.Visibility -ne [System.Windows.Visibility]::Visible -or !$icon.IsTaskbarIconCreated) {
        throw 'FAIL: The tray icon must exist immediately on normal startup.'
    }
    'PASS: The tray icon exists on normal startup.'
    $window.Hide()
    $icon.Visibility = [System.Windows.Visibility]::Visible
    # Replay the shell notification at the library's message-processing boundary,
    # not a direct call to the app handler or ContextMenu.IsOpen setter.
    $sink = $icon.GetType().GetField('messageSink', $flags).GetValue($icon)
    $processMessage = $sink.GetType().GetMethod('ProcessWindowMessage', $flags)
    $callback = $sink.GetType().GetField('CallbackMessageId',
        [Reflection.BindingFlags]'Static,NonPublic,Public').GetValue($null)

    foreach ($protocol in @('right-button', 'context-menu', 'combined')) {
        $icon.ContextMenu.IsOpen = $false
        $messages = switch ($protocol) {
            'right-button' { @(0x204, 0x205) } # WM_RBUTTONDOWN/UP
            'context-menu' { @(0x7b) }        # WM_CONTEXTMENU (v4/keyboard)
            'combined' { @(0x204, 0x205, 0x7b) }
        }
        foreach ($message in $messages) {
            $processMessage.Invoke($sink, @([uint32]$callback, [IntPtr]0, [IntPtr]$message)) | Out-Null
        }
        if (!$icon.ContextMenu.IsOpen) {
            throw "FAIL: $protocol notification did not open the hidden app's tray menu."
        }
        $headers = @($icon.ContextMenu.Items | ForEach-Object { $_.Header })
        if (($headers -join ',') -ne 'Show,Exit') {
            throw 'FAIL: The tray menu must expose Show and Exit.'
        }
        "PASS: $protocol notification opens Show/Exit while the app is hidden."
    }

    $icon.ContextMenu.IsOpen = $false
    $showItem = $icon.ContextMenu.Items[0]
    $showItem.RaiseEvent((New-Object System.Windows.RoutedEventArgs ([System.Windows.Controls.MenuItem]::ClickEvent)))
    if (!$window.IsVisible -or $window.WindowState -ne [System.Windows.WindowState]::Normal -or
        $icon.Visibility -ne [System.Windows.Visibility]::Visible -or !$icon.IsTaskbarIconCreated) {
        throw 'FAIL: Show did not restore the window and keep its tray icon.'
    }
    'PASS: Show restores the main window without removing the tray icon.'
} finally {
    $icon.ContextMenu.IsOpen = $false
    $icon.Dispose()
    $window.GetType().GetField('_exiting', $flags).SetValue($window, $true)
    $window.Close()
}
