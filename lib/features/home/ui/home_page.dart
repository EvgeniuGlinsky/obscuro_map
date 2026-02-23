import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'home_view.dart';

class HomePage extends StatelessWidget {
  final TileLayer map;

  const HomePage({
    super.key,
    required this.map,
  });

  @override
  Widget build(BuildContext context) {
    return HomeView(map: map);
  }
}
