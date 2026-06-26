# Body Debt

Body Debt is a Flutter-based mobile application designed to track and simulate daily energy levels. It helps users visualize how sleep patterns, "body debt" (accumulated sleep deprivation), and hydration affect their vitality throughout the day.

## Project Information
- **Course:** Multiplatform Mobile Software Engineering in Practice (2025/2026)
- **University:** AGH University of Science and Technology, Krakow (Erasmus+ Program)
- **Professor:** Mateusz Danioł

## Authors
- **Alberto Russo** (Italy)
- **Tamari Khotcholava** (Georgia)

## Key Features
- **Energy Simulation Engine:** A robust algorithm that calculates real-time energy levels considering:
    - **Historical Sleep Debt:** Analyzes a rolling window of sleep data to determine long-term fatigue.
    - **Circadian Rhythms:** Models natural energy fluctuations using sinusoidal curves.
    - **Hydration Tracking:** Adjusts energy levels dynamically based on water intake vs. hours awake.
- **Interactive Energy Curves:** Visualizes energy trends for the current day and provides future projections (Forecasts).
- **Precise Activity Logging:** Allows users to log specific wake-up and bedtimes for high-accuracy simulations.
- **Background Notifications:** Integrates `Workmanager` and `flutter_local_notifications` to provide hydration reminders and energy status updates.
- **Smart Recommendations:** Suggests ideal bedtimes based on current energy debt.

## Technical Details
- **Architecture:** MVVM (Model-View-ViewModel) with a Repository pattern for data persistence.
- **Simulation Logic:** Contained within `SimulationRepository`, managing complex state transitions between historical logs and real-time inputs.
- **State Management:** [Provider](https://pub.dev/packages/provider).
- **Persistence:** Local storage via `shared_preferences`.

## Getting Started

### Prerequisites
- Flutter SDK (>= 3.10.3)
- Android Studio or VS Code

### Installation
1. Clone the repository.
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the application:
   ```bash
   flutter run
   ```

---
*Created as part of the Erasmus+ experience at AGH University, Krakow.*
