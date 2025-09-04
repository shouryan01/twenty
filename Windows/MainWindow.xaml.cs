using System;
using System.Windows;
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

        public MainWindow()
        {
            InitializeComponent();
            _timer = new DispatcherTimer();
            _timer.Interval = TimeSpan.FromSeconds(1);
            _timer.Tick += Timer_Tick;
            ResetTimer();
        }

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
            Application.Current.Shutdown();
        }

        private void ShowAndRestoreWindow()
        {
            this.Show();
            this.WindowState = WindowState.Normal;
            this.Activate();
            MyNotifyIcon.Visibility = Visibility.Collapsed;
        }

        protected override void OnClosing(System.ComponentModel.CancelEventArgs e)
        {
            MyNotifyIcon.Dispose();
            base.OnClosing(e);
        }

        #endregion

        private void Timer_Tick(object? sender, EventArgs e)
        {
            _currentTime = _currentTime.Add(TimeSpan.FromSeconds(-1));
            TimerTextBlock.Text = _currentTime.ToString(@"mm\:ss");

            if (_currentTime <= TimeSpan.Zero)
            {
                if (_isWorkTime)
                {
                    _originalState = this.WindowState;
                    _originalTop = this.Top;
                    _originalLeft = this.Left;
                    _originalWidth = this.Width;
                    _originalHeight = this.Height;

                    this.Topmost = true;
                    this.WindowStyle = WindowStyle.None;

                    ShowAndRestoreWindow();
                    this.WindowState = WindowState.Maximized;

                    this.Activate();

                    _isWorkTime = false;
                    _currentTime = _breakTime;
                    StatusTextBlock.Text = "Break Time!";
                    StatusTextBlock.Foreground = Brushes.Green;
                }
                else
                {
                    this.Topmost = false;
                    this.WindowStyle = WindowStyle.SingleBorderWindow;
                    this.WindowState = _originalState;
                    this.Top = _originalTop;
                    this.Left = _originalLeft;
                    this.Width = _originalWidth;
                    this.Height = _originalHeight;

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
            if (SettingsPanel.Visibility == Visibility.Collapsed)
            {
                SettingsPanel.Visibility = Visibility.Visible;
            }
            else
            {
                SettingsPanel.Visibility = Visibility.Collapsed;
            }
        }
    }
}
