import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleMeshGroup {
  final String name;
  final List<ScanResult> nodes;

  BleMeshGroup(this.name, this.nodes);
}
