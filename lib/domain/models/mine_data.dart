class ZoneData {
  final String name;
  final List<String> sorties;

  ZoneData({required this.name, required this.sorties});
}

class MineData {
  final String name;
  final List<ZoneData> zones;

  MineData({required this.name, required this.zones});
}

// Static mine/zone/sortie data
final List<MineData> minesData = [
  MineData(
    name: 'Mine G',
    zones: [
      ZoneData(
        name: 'Mine G Zone Dragline',
        sorties: ['Sortie 1', 'Sortie 2'],
      ),
    ],
  ),
  MineData(
    name: 'Mine E',
    zones: [
      ZoneData(
        name: 'Mine E1 Zone Dragline',
        sorties: ['Sortie 1', 'Sortie 2', 'Sortie 3', 'Sortie 4'],
      ),
      ZoneData(
        name: 'Mine E1 Zone Bulls',
        sorties: ['Sortie 2', 'Sortie 3'],
      ),
      ZoneData(
        name: 'Mine E3 Zone Dragline',
        sorties: ['Sortie -1', 'Sortie 0', 'Sortie 1', 'Sortie 2'],
      ),
      ZoneData(
        name: 'Mine E2 Zone Bulls',
        sorties: ['Sortie 1', 'Sortie 2', 'Sortie 3'],
      ),
    ],
  ),
  MineData(
    name: 'Mine C',
    zones: [
      ZoneData(
        name: 'Mine C Zone Dragline',
        sorties: [],
      ),
    ],
  ),
  MineData(
    name: 'Mine A',
    zones: [
      ZoneData(
        name: 'Mine A',
        sorties: ['Sortie 1', 'Sortie 2', 'Sortie 3', 'Sortie 4', 'Sortie 5', 'Sortie 6', 'Sortie 7'],
      ),
    ],
  ),
];