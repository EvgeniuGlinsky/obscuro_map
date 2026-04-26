/// Google Maps style JSON tuned to the design hand-off
/// (`new_design/README.md` → "Фон карты"):
///
///   suelo  #E8E3D8 · вода #AAD3DF · парки #C8DFAF
///   главные дороги  #FFFFFF · второстепенные #F0EDE6 · малые #EAE6DE
///
/// Minor stylistic choices on top of the spec:
///   - business / transit POI markers hidden — they fight the fog texture
///     and aren't needed for fog-of-war exploration.
///   - road labels kept (with a soft dark stroke so they read against the
///     light land tone) so users can still navigate.
///
/// Apply via `GoogleMapController.setMapStyle(kMapStyleJson)` once on
/// map-ready; cheap idempotent call so it's also safe on re-mount.
const String kMapStyleJson = r'''
[
  {"featureType":"all","elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.business","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},

  {"featureType":"landscape","elementType":"geometry.fill","stylers":[{"color":"#E8E3D8"}]},
  {"featureType":"landscape.man_made","elementType":"geometry.fill","stylers":[{"color":"#DADAD6"}]},
  {"featureType":"landscape.natural.terrain","elementType":"geometry.fill","stylers":[{"color":"#E1DCD0"}]},

  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#AAD3DF"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#5B7A87"}]},
  {"featureType":"water","elementType":"labels.text.stroke","stylers":[{"color":"#AAD3DF"}]},

  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#C8DFAF"}]},
  {"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#4F6B3F"}]},
  {"featureType":"poi.park","elementType":"labels.text.stroke","stylers":[{"color":"#C8DFAF"}]},

  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#3D3360"}]},
  {"featureType":"road","elementType":"labels.text.stroke","stylers":[{"color":"#FFFFFF"}]},

  {"featureType":"road.highway","elementType":"geometry.fill","stylers":[{"color":"#FFFFFF"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#D9D2C2"}]},
  {"featureType":"road.arterial","elementType":"geometry.fill","stylers":[{"color":"#F0EDE6"}]},
  {"featureType":"road.arterial","elementType":"geometry.stroke","stylers":[{"color":"#D9D2C2"}]},
  {"featureType":"road.local","elementType":"geometry.fill","stylers":[{"color":"#EAE6DE"}]},
  {"featureType":"road.local","elementType":"geometry.stroke","stylers":[{"color":"#D9D2C2"}]},

  {"featureType":"administrative","elementType":"geometry.stroke","stylers":[{"color":"#C5BFAE"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#3D3360"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.stroke","stylers":[{"color":"#E8E3D8"}]}
]
''';
