using System.Text;

using System.Windows;

using System.Windows.Controls;

using System.Windows.Data;

using System.Windows.Documents;

using System.Windows.Input;

using System.Windows.Media;

using System.Windows.Media.Imaging;

using System.Windows.Navigation;

using System.Windows.Shapes;

using System.Windows.Threading; // Important: Add this for the timer



namespace twenty

{

    /// <summary>

    /// Interaction logic for MainWindow.xaml

    /// </summary>

    public partial class MainWindow : Window

    {

        private readonly DispatcherTimer _timer;

        // --- MODIFIED: Removed initial hardcoded values ---

        private TimeSpan _workTime;

        private TimeSpan _breakTime;

        private TimeSpan _currentTime;

        private bool _isWorkTime = true;



        public MainWindow()

        {

            InitializeComponent();



            // Set up the timer

            _timer = new DispatcherTimer();

            _timer.Interval = TimeSpan.FromSeconds(1); // Timer ticks every second

            _timer.Tick += Timer_Tick; // This method will be called on each tick



            // Initialize the UI

            ResetTimer();

        }



        private void Timer_Tick(object? sender, EventArgs e)

        {

            // Decrement the current time

            _currentTime = _currentTime.Add(TimeSpan.FromSeconds(-1));

            TimerTextBlock.Text = _currentTime.ToString(@"mm\:ss");



            // Check if the timer has reached zero

            if (_currentTime <= TimeSpan.Zero)
            {
                if (_isWorkTime)
                {
                    // ... (break time logic is the same) ...
                    _isWorkTime = false;
                    _currentTime = _breakTime;
                    StatusTextBlock.Text = "Break Time!";
                    StatusTextBlock.Foreground = Brushes.Green; // This is fine for a status color
                    this.Activate();
                }
                else
                {
                    // Switch back to work time
                    _isWorkTime = true;
                    _currentTime = _workTime;
                    StatusTextBlock.Text = "Work Time";

                    // --- MODIFIED: Clear the hardcoded color ---
                    // This makes it use the theme color from the XAML again.
                    StatusTextBlock.ClearValue(TextBlock.ForegroundProperty);
                }
            }

        }



        private void StartButton_Click(object sender, RoutedEventArgs e)

        {

            // --- MODIFIED: Parse input before starting ---

            if (StatusTextBlock.Text == "Ready")

            {

                if (!ParseTimesFromUI()) return; // Exit if input is invalid

                _currentTime = _workTime; // Set current time to the new work time

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

            // --- MODIFIED: Clear the hardcoded color ---
            StatusTextBlock.ClearValue(TextBlock.ForegroundProperty);

            StartButton.IsEnabled = true;
            StopButton.IsEnabled = false;
        }



        // --- NEW METHOD: Parses and validates user input ---

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



                _workTime = TimeSpan.FromSeconds(workTime);

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