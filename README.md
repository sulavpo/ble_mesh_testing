# BLE Mesh Testing

This Flutter app, built using the `flutter_blue_plus` package, scans and identifies both BLE and BLE Mesh devices. It differentiates between standard BLE and BLE Mesh devices, while also detecting their provisioning status. It serves as a foundation for further exploration of BLE Mesh functionalities like message relaying and secure provisioning.

## BLE & BLE Mesh Device Filter - Flutter Application

This Flutter app is designed to scan, identify, and differentiate between regular Bluetooth Low Energy (BLE) devices and BLE Mesh devices. Built using the `flutter_blue_plus` package, the app incorporates advanced functionality for identifying key characteristics of BLE Mesh devices, including their provisioning status.

## Project Overview:
This project simplifies the process of discovering BLE and BLE Mesh devices while providing a foundation for working with BLE Mesh protocols in Flutter. It introduces a filter mechanism that:
- Distinguishes between regular BLE and BLE Mesh devices
- Determines whether a BLE Mesh device is provisioned or unprovisioned

## Key Features:
- **Comprehensive Device Scanning:** Continuously scans for nearby Bluetooth devices, allowing for real-time discovery of both regular BLE and BLE Mesh devices. Filters out noise to identify only relevant devices.
- **Device Identification and Differentiation:** Distinguishes between standard BLE devices and BLE Mesh nodes. This feature is crucial for working with complex Bluetooth networks.
- **Provisioning Status Detection:** Detects whether a BLE Mesh device is provisioned or unprovisioned within the BLE Mesh network, helping developers determine which devices are part of the network and which require provisioning.

## BLE Mesh Protocol Exploration:
The app lays the groundwork for further development into BLE Mesh-specific functionalities:
- **Message Relaying:** Understanding how messages are routed through relay nodes in the BLE Mesh network.
- **Replay Protection:** Implementing security mechanisms to protect the network from replay attacks by ensuring message freshness.
- **Secure Provisioning:** Securely adding new devices to the BLE Mesh network through cryptographic measures.

## Technologies Used:
- **Flutter:** For cross-platform compatibility.
- **flutter_blue_plus package:** Used for BLE communication, device scanning, and connection.

## Future Work:
The current version serves as a foundation for integrating more advanced BLE Mesh functionalities:
- **Message Relaying and Communication:** Implement and test message relaying between BLE Mesh nodes.
- **Security Features:** Introduce replay protection and secure provisioning.
- **Node Management:** Add features for managing nodes, including adding and removing devices dynamically.

## How to Use:
1. Clone the repository and set up the Flutter development environment.
2. Install the required dependencies by running `flutter pub get`.
3. Run the app on a physical device with Bluetooth capabilities.
4. Use the app to scan and identify BLE and BLE Mesh devices, and check their provisioning status.

This project serves as a starting point for developers working with BLE Mesh technology in Flutter, aiming to expand into more complex Bluetooth applications.
