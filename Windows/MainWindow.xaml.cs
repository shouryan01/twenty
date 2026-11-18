using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Threading;
using Microsoft.Toolkit.Uwp.Notifications;
using Hardcodet.Wpf.TaskbarNotification;

namespace twenty
{
    public partial class MainWindow : Window
    {
        private readonly DispatcherTimer _timer;
        private TimeSpan _workTime;
        private TimeSpan _breakTime;
        private TimeSpan _currentTime;
        private bool _isWorkTime = true;

        private double _originalTop, _originalLeft, _originalWidth, _originalHeight;
        private WindowState _originalState;

        private readonly List<Window> _overlays = new();
        private readonly List<TextBlock> _overlayTimers = new();

        private delegate bool MonitorEnumProc(IntPtr hMonitor, IntPtr hdc, ref RECT rect, IntPtr data);

        [StructLayout(LayoutKind.Sequential)]
        private struct RECT { public int Left, Top, Right, Bottom; }

        [DllImport("user32.dll")]
        private static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr clip, MonitorEnumProc proc, IntPtr data);

        [DllImport("user32.dll")]
        private static extern IntPtr MonitorFromWindow(IntPtr hwnd, uint flags);

        [DllImport("user32.dll")]
        private static extern bool SetWindowPos(IntPtr hwnd, IntPtr after, int x, int y, int cx, int cy, uint flags);

        private static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
        private const uint SWP_NOACTIVATE = 0x0010;
        private const uint SWP_SHOWWINDOW = 0x0040;

        // Shows a break overlay on every monitor except the one the main window uses.
        private void ShowOverlays()
        {
            CloseOverlays();
            var monitors = new List<(IntPtr Handle, RECT Rect)>();
            EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, (IntPtr h, IntPtr dc, ref RECT r, IntPtr d) =>
            {
                monitors.Add((h, r));
                return true;
            }, IntPtr.Zero);

            foreach (var (handle, r) in monitors)
            {
                var timerText = new TextBlock
                {
                    Text = _breakTime.ToString(@"mm\:ss"),
                    FontSize = 72,
                    FontWeight = FontWeights.Bold,
                    FontFamily = new FontFamily("Segoe UI"),
                    Foreground = Brushes.White,
                    HorizontalAlignment = HorizontalAlignment.Center
                };
                var panel = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
                panel.Children.Add(new TextBlock
                {
                    Text = "Break Time!",
                    FontSize = 24,
                    FontWeight = FontWeights.Bold,
                    Foreground = Brushes.Green,
                    HorizontalAlignment = HorizontalAlignment.Center,
                    Margin = new Thickness(0, 0, 0, 10)
                });
                panel.Children.Add(timerText);

                var overlay = new Window
                {
                    WindowStyle = WindowStyle.None,
                    ResizeMode = ResizeMode.NoResize,
                    ShowInTaskbar = false,
                    Topmost = true,
                    ShowActivated = false,
                    Background = Brushes.Black,
                    Content = panel
                };
                overlay.Show();
                var hwnd = new WindowInteropHelper(overlay).Handle;
                SetWindowPos(hwnd, HWND_TOPMOST, r.Left, r.Top, r.Right - r.Left, r.Bottom - r.Top,
                    SWP_NOACTIVATE | SWP_SHOWWINDOW);

                _overlays.Add(overlay);
                _overlayTimers.Add(timerText);
            }
        }

        private const uint SWP_NOSIZE = 0x0001;
        private const uint SWP_NOMOVE = 0x0002;
        private static readonly IntPtr HWND_BOTTOM = new IntPtr(1);

        // Closing the overlays can make Windows activate this window.
        // Put it behind all other windows, and again after the activation has happened.
        private void SendToBack()
        {
            void Push()
            {
                var hwnd = new WindowInteropHelper(this).Handle;
                if (hwnd == IntPtr.Zero) return;
                SetWindowPos(hwnd, HWND_BOTTOM, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
            }
            Push();
            Dispatcher.BeginInvoke(DispatcherPriority.ApplicationIdle, new Action(Push));
        }

        private void CloseOverlays()
        {
            foreach (var o in _overlays) o.Close();
            _overlays.Clear();
            _overlayTimers.Clear();
        }

        public MainWindow()
        {
            ApplyThemeResources();
            InitializeComponent();
            LoadSettings();
            WorkTimeTextBox.TextChanged += (_, _) => SaveSettings();
            BreakTimeTextBox.TextChanged += (_, _) => SaveSettings();
            _timer = new DispatcherTimer();
            _timer.Interval = TimeSpan.FromSeconds(1);
            _timer.Tick += Timer_Tick;
            ResetTimer();

            // Let Windows shut down or sign out without the tray logic blocking it.
            Application.Current.SessionEnding += (_, _) => _exiting = true;

            StartupCheckBox.IsChecked = IsStartupEnabled();
            Loaded += (_, _) =>
            {
                if (Array.Exists(Environment.GetCommandLineArgs(), a => a == StartupArg))
                {
                    // Started by Windows at sign-in: go to the tray and start the timer.
                    this.Hide();
                    MyNotifyIcon.Visibility = Visibility.Visible;
                    StartButton_Click(this, new RoutedEventArgs());
                }
            };
        }

        #region Saved settings

        private sealed class Settings
        {
            public string WorkMinutes { get; set; } = "20";
            public string BreakSeconds { get; set; } = "20";
        }

        private static string SettingsPath => System.IO.Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "twenty", "settings.json");

        private void LoadSettings()
        {
            try
            {
                if (!System.IO.File.Exists(SettingsPath)) return;
                var s = System.Text.Json.JsonSerializer.Deserialize<Settings>(System.IO.File.ReadAllText(SettingsPath));
                if (s == null) return;
                if (int.TryParse(s.WorkMinutes, out int w) && w > 0) WorkTimeTextBox.Text = s.WorkMinutes;
                if (int.TryParse(s.BreakSeconds, out int b) && b > 0) BreakTimeTextBox.Text = s.BreakSeconds;
            }
            catch { /* A bad settings file must not stop the app. Use the defaults. */ }
        }

        private void SaveSettings()
        {
            try
            {
                // Save only valid values.
                if (!(int.TryParse(WorkTimeTextBox.Text, out int w) && w > 0 &&
                      int.TryParse(BreakTimeTextBox.Text, out int b) && b > 0)) return;
                System.IO.Directory.CreateDirectory(System.IO.Path.GetDirectoryName(SettingsPath)!);
                System.IO.File.WriteAllText(SettingsPath, System.Text.Json.JsonSerializer.Serialize(
                    new Settings { WorkMinutes = WorkTimeTextBox.Text, BreakSeconds = BreakTimeTextBox.Text }));
            }
            catch { /* Saving is a convenience. Ignore disk errors. */ }
        }

        #endregion

        #region Start with Windows

        private const string StartupArg = "--startup";
        private const string RunKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
        private const string RunValueName = "twenty";

        private static bool IsStartupEnabled()
        {
            try
            {
                using var key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(RunKeyPath);
                return key?.GetValue(RunValueName) is string;
            }
            catch { return false; }
        }

        private static void SetStartupEnabled(bool enabled)
        {
            using var key = Microsoft.Win32.Registry.CurrentUser.CreateSubKey(RunKeyPath);
            if (enabled)
                key.SetValue(RunValueName, $"\"{Environment.ProcessPath}\" {StartupArg}");
            else
                key.DeleteValue(RunValueName, false);
        }

        private void StartupCheckBox_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                SetStartupEnabled(StartupCheckBox.IsChecked == true);
            }
            catch (Exception ex)
            {
                StartupCheckBox.IsChecked = IsStartupEnabled();
                MessageBox.Show("Could not change the startup setting: " + ex.Message, "twenty",
                    MessageBoxButton.OK, MessageBoxImage.Warning);
            }
        }

        #endregion

        #region System Tray Logic

        private void MainWindow_StateChanged(object sender, EventArgs e)
        {
            if (this.WindowState == WindowState.Minimized)
            {
                this.Hide();
                MyNotifyIcon.Visibility = Visibility.Visible;
            }
        }

        private void NotifyIcon_DoubleClick(object sender, RoutedEventArgs e)
        {
            ShowAndRestoreWindow();
        }

        private void ShowMenuItem_Click(object sender, RoutedEventArgs e)
        {
            ShowAndRestoreWindow();
        }

        private void ExitMenuItem_Click(object sender, RoutedEventArgs e)
        {
            _exiting = true;
            Application.Current.Shutdown();
        }

        private void ShowAndRestoreWindow()
        {
            this.Show();
            this.WindowState = WindowState.Normal;
            this.Activate();
            MyNotifyIcon.Visibility = Visibility.Collapsed;
        }

        private bool _exiting;

        protected override void OnClosing(System.ComponentModel.CancelEventArgs e)
        {
            if (!_exiting)
            {
                // The close button hides the window. The app keeps running in the system tray.
                e.Cancel = true;
                this.Hide();
                MyNotifyIcon.Visibility = Visibility.Visible;
                return;
            }
            MyNotifyIcon.Dispose();
            base.OnClosing(e);
        }

        #endregion

        private static bool IsDarkTheme()
        {
            try
            {
                using var key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(
                    @"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
                return key?.GetValue("AppsUseLightTheme") is int v && v == 0;
            }
            catch { return false; }
        }

        private void ApplyThemeResources()
        {
            bool dark = IsDarkTheme();
            SolidColorBrush Brush(byte a, byte r, byte g, byte b)
            {
                var br = new SolidColorBrush(Color.FromArgb(a, r, g, b));
                br.Freeze();
                return br;
            }
            Resources["Fg"] = dark ? Brush(255, 255, 255, 255) : Brush(255, 0, 0, 0);
            Resources["FgMuted"] = dark ? Brush(255, 209, 213, 219) : Brush(255, 60, 60, 70);
            Resources["InputBg"] = dark ? Brush(0x22, 255, 255, 255) : Brush(0x0F, 0, 0, 0);
            Resources["InputBorder"] = dark ? Brush(0x55, 255, 255, 255) : Brush(0x33, 0, 0, 0);
        }

        protected override void OnSourceInitialized(EventArgs e)
        {
            base.OnSourceInitialized(e);
            var hwnd = new WindowInteropHelper(this).Handle;
            HwndSource.FromHwnd(hwnd).CompositionTarget.BackgroundColor = Colors.Transparent;
            var margins = new MARGINS { Left = -1, Right = -1, Top = -1, Bottom = -1 };
            DwmExtendFrameIntoClientArea(hwnd, ref margins);
            int useDark = IsDarkTheme() ? 1 : 0;
            DwmSetWindowAttribute(hwnd, 20, ref useDark, sizeof(int)); // title bar follows the theme
            int mica = 2; // Mica: the same material as the title bar
            DwmSetWindowAttribute(hwnd, 38, ref mica, sizeof(int));
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct MARGINS { public int Left, Right, Top, Bottom; }

        [DllImport("dwmapi.dll")]
        private static extern int DwmExtendFrameIntoClientArea(IntPtr hwnd, ref MARGINS margins);

        [DllImport("dwmapi.dll")]
        private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);

        private void Timer_Tick(object? sender, EventArgs e)
        {
            _currentTime = _currentTime.Add(TimeSpan.FromSeconds(-1));
            TimerTextBlock.Text = _currentTime.ToString(@"mm\:ss");
            foreach (var t in _overlayTimers)
            {
                t.Text = _currentTime > TimeSpan.Zero ? _currentTime.ToString(@"mm\:ss") : "00:00";
            }

            if (_currentTime <= TimeSpan.Zero)
            {
                if (_isWorkTime)
                {
                    ShowOverlays();

                    _isWorkTime = false;
                    _currentTime = _breakTime;
                    StatusTextBlock.Text = "Break Time!";
                    StatusTextBlock.Foreground = new SolidColorBrush(Color.FromRgb(0x4A, 0xDE, 0x80));
                }
                else
                {
                    CloseOverlays();
                    SendToBack();

                    _isWorkTime = true;
                    _currentTime = _workTime;
                    StatusTextBlock.Text = "Work Time";
                    StatusTextBlock.ClearValue(TextBlock.ForegroundProperty);
                }
            }
        }

        private void ShowNotification(string title, string message)
        {
            new ToastContentBuilder()
              .AddText(title)
              .AddText(message)
              .Show();
        }

        private void StartButton_Click(object sender, RoutedEventArgs e)
        {
            if (StatusTextBlock.Text == "Ready")
            {
                if (!ParseTimesFromUI()) return;
                _currentTime = _workTime;
            }

            _timer.Start();
            StartButton.IsEnabled = false;
            StopButton.IsEnabled = true;
            if (StatusTextBlock.Text == "Ready")
            {
                StatusTextBlock.Text = "Work Time";
            }
        }

        private void StopButton_Click(object sender, RoutedEventArgs e)
        {
            _timer.Stop();
            CloseOverlays();
            StartButton.IsEnabled = true;
            StopButton.IsEnabled = false;
        }

        private void ResetButton_Click(object sender, RoutedEventArgs e)
        {
            ResetTimer();
        }

        private void ResetTimer()
        {
            _timer.Stop();
            CloseOverlays();

            if (!ParseTimesFromUI())
            {
                StartButton.IsEnabled = true;
                StopButton.IsEnabled = false;
                return;
            }

            _isWorkTime = true;
            _currentTime = _workTime;
            TimerTextBlock.Text = _currentTime.ToString(@"mm\:ss");
            StatusTextBlock.Text = "Ready";
            StatusTextBlock.ClearValue(TextBlock.ForegroundProperty);
            StartButton.IsEnabled = true;
            StopButton.IsEnabled = false;
        }

        private bool ParseTimesFromUI()
        {
            if (int.TryParse(WorkTimeTextBox.Text, out int workTime) &&
                int.TryParse(BreakTimeTextBox.Text, out int breakTime))
            {
                if (workTime <= 0 || breakTime <= 0)
                {
                    MessageBox.Show("Time values must be positive numbers.", "Invalid Input", MessageBoxButton.OK, MessageBoxImage.Warning);
                    return false;
                }
                _workTime = TimeSpan.FromMinutes(workTime);
                _breakTime = TimeSpan.FromSeconds(breakTime);
                return true;
            }
            else
            {
                MessageBox.Show("Please enter valid numbers for work and break times.", "Invalid Input", MessageBoxButton.OK, MessageBoxImage.Error);
                return false;
            }
        }

        private void SettingsButton_Click(object sender, RoutedEventArgs e)
        {
            bool open = SettingsPanel.Visibility == Visibility.Collapsed;
            SettingsPanel.Visibility = open ? Visibility.Visible : Visibility.Collapsed;
            ButtonsPanel.Visibility = open ? Visibility.Collapsed : Visibility.Visible;
            StatusTextBlock.Visibility = open ? Visibility.Collapsed : Visibility.Visible;
            TimerTextBlock.Visibility = open ? Visibility.Collapsed : Visibility.Visible;
        }
    }
}
