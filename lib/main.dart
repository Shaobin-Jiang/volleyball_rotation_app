import 'dart:convert';

import 'package:flutter/material.dart';

import 'storage/storage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Volleyball Rotation',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E7490)),
        useMaterial3: true,
      ),
      home: const PlayerEntryPage(),
    );
  }
}

class PlayerEntryPage extends StatefulWidget {
  const PlayerEntryPage({super.key});

  @override
  State<PlayerEntryPage> createState() => _PlayerEntryPageState();
}

class _PlayerEntryPageState extends State<PlayerEntryPage> {
  final List<TextEditingController> _controllers =
      List<TextEditingController>.generate(6, (_) => TextEditingController());

  @override
  void initState() {
    super.initState();
    _loadSavedRoster();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSavedRoster() async {
    try {
      final stored = await readStoredString(rosterStorageKey);
      if (stored == null || !mounted) {
        return;
      }
      final decoded = jsonDecode(stored) as Map<String, dynamic>;
      final names = decoded['playerNames'] as List<dynamic>?;
      if (names == null || names.length != 6) {
        return;
      }
      for (var i = 0; i < 6; i++) {
        _controllers[i].text = (names[i] as String?) ?? '';
      }
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load saved player roster.')),
      );
    }
  }

  Future<void> _saveRoster(List<String> names) async {
    await writeStoredString(
      rosterStorageKey,
      jsonEncode({'playerNames': names}),
    );
  }

  Future<void> _openRotationPage() async {
    final names = _controllers
        .map((controller) => controller.text.trim())
        .toList();
    final hasEmpty = names.any((name) => name.isEmpty);
    if (hasEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter all 6 player names.')),
      );
      return;
    }

    try {
      await _saveRoster(names);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save player roster.')),
        );
      }
    }

    if (!mounted) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => RotationPage(playerNames: names)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter Roster')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Players are entered in starting rotation order: position 1 to 6.',
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: 6,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    return TextField(
                      controller: _controllers[index],
                      textInputAction: index == 5
                          ? TextInputAction.done
                          : TextInputAction.next,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText:
                            'Player ${index + 1} (starts at position ${index + 1})',
                      ),
                    );
                  },
                ),
              ),
              FilledButton(
                onPressed: _openRotationPage,
                child: const Text('Open Rotation Board'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RotationPage extends StatefulWidget {
  const RotationPage({super.key, required this.playerNames});

  final List<String> playerNames;

  @override
  State<RotationPage> createState() => _RotationPageState();
}

class _RotationPageState extends State<RotationPage> {
  static const List<int> _clockwiseCycle = [1, 6, 5, 4, 3, 2];
  static const List<int> _gridOrder = [4, 3, 2, 5, 6, 1];
  static const double _cardWidth = 34;
  static const double _cardHeight = 34;

  final Map<int, Map<int, Offset>> _savedOffsetsByRotation =
      <int, Map<int, Offset>>{};

  late List<int> _playerAtPosition;
  final Map<int, Offset> _currentOffsets = <int, Offset>{};
  int _activeOffsetsRotation = -1;
  Size _offsetsCourtSize = Size.zero;
  Size _currentCourtSize = Size.zero;

  int _rotationIndex = 0;
  bool _isLoadingStorage = true;

  @override
  void initState() {
    super.initState();
    _playerAtPosition = List<int>.generate(7, (index) => index - 1);
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    try {
      final stored = await readStoredString(positionsStorageKey);
      if (stored != null) {
        final decoded = jsonDecode(stored) as Map<String, dynamic>;
        final playersRaw = decoded['players'] as List<dynamic>?;
        if (playersRaw != null && playersRaw.length == 6) {
          for (var i = 0; i < 6; i++) {
            _playerAtPosition[i + 1] = (playersRaw[i] as num).toInt();
          }
        }

        final rotationRaw = decoded['rotationIndex'];
        if (rotationRaw is num) {
          _rotationIndex = rotationRaw.toInt() % 6;
          if (_rotationIndex < 0) {
            _rotationIndex += 6;
          }
        }

        final savedOffsets = decoded['offsets'] as Map<String, dynamic>?;
        if (savedOffsets != null) {
          savedOffsets.forEach((rotationKey, value) {
            final rotation = int.tryParse(rotationKey);
            if (rotation == null || value is! Map<String, dynamic>) {
              return;
            }
            final offsetMap = <int, Offset>{};
            value.forEach((playerKey, point) {
              if (point is! Map<String, dynamic>) {
                return;
              }
              final player = int.tryParse(playerKey);
              if (player == null) {
                return;
              }
              final x = (point['x'] as num?)?.toDouble();
              final y = (point['y'] as num?)?.toDouble();
              if (x != null && y != null) {
                offsetMap[player] = Offset(x, y);
              }
            });
            if (offsetMap.length == 6) {
              _savedOffsetsByRotation[rotation] = offsetMap;
            }
          });
        }
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load saved rotations.')),
      );
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _isLoadingStorage = false;
    });
  }

  Future<void> _saveCurrentState() async {
    final offsetsJson = <String, dynamic>{};
    _savedOffsetsByRotation.forEach((rotation, offsetMap) {
      offsetsJson['$rotation'] = {
        for (final entry in offsetMap.entries)
          '${entry.key}': {'x': entry.value.dx, 'y': entry.value.dy},
      };
    });

    final payload = {
      'rotationIndex': _rotationIndex,
      'players': [
        for (var position = 1; position <= 6; position++)
          _playerAtPosition[position],
      ],
      'offsets': offsetsJson,
    };
    try {
      await writeStoredString(positionsStorageKey, jsonEncode(payload));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not save rotations.')),
        );
    }
  }

  Map<int, Offset> _defaultOffsets(Size courtSize) {
    final leftMargin = 12.0;
    final topMargin = 16.0;
    final colWidth = (courtSize.width - leftMargin * 2 - _cardWidth) / 2;
    final rowHeight = (courtSize.height - topMargin * 2 - _cardHeight) / 1;

    final positionToPoint = <int, Offset>{
      4: Offset(leftMargin + colWidth * 0, topMargin),
      3: Offset(leftMargin + colWidth * 1, topMargin),
      2: Offset(leftMargin + colWidth * 2, topMargin),
      5: Offset(leftMargin + colWidth * 0, topMargin + rowHeight),
      6: Offset(leftMargin + colWidth * 1, topMargin + rowHeight),
      1: Offset(leftMargin + colWidth * 2, topMargin + rowHeight),
    };

    return {
      for (var position = 1; position <= 6; position++)
        _playerAtPosition[position]: positionToPoint[position]!,
    };
  }

  void _ensureCurrentOffsets(Size courtSize) {
    if (_activeOffsetsRotation == _rotationIndex &&
        _currentOffsets.length == 6 &&
        _offsetsCourtSize == courtSize) {
      return;
    }

    final saved = _savedOffsetsByRotation[_rotationIndex];
    if (saved != null && saved.length == 6) {
      _currentOffsets
        ..clear()
        ..addAll(
          saved.map(
            (key, value) => MapEntry(key, _clampOffset(value, courtSize)),
          ),
        );
      _activeOffsetsRotation = _rotationIndex;
      _offsetsCourtSize = courtSize;
      return;
    }

    _currentOffsets
      ..clear()
      ..addAll(_defaultOffsets(courtSize));
    _activeOffsetsRotation = _rotationIndex;
    _offsetsCourtSize = courtSize;
    _savedOffsetsByRotation[_rotationIndex] = Map<int, Offset>.from(
      _currentOffsets,
    );
    _saveCurrentState();
  }

  Offset _clampOffset(Offset offset, Size courtSize) {
    final maxX = courtSize.width - _cardWidth;
    final maxY = courtSize.height - _cardHeight;
    return Offset(offset.dx.clamp(0.0, maxX), offset.dy.clamp(0.0, maxY));
  }

  bool _isLegalByRotationRule(Map<int, Offset> offsets) {
    Offset positionOffset(int position) =>
        offsets[_playerAtPosition[position]]!;

    final p4 = positionOffset(4);
    final p3 = positionOffset(3);
    final p2 = positionOffset(2);
    final p5 = positionOffset(5);
    final p6 = positionOffset(6);
    final p1 = positionOffset(1);

    final frontInFront = p4.dy < p5.dy && p3.dy < p6.dy && p2.dy < p1.dy;
    final frontLeftToRight = p4.dx < p3.dx && p3.dx < p2.dx;
    final backLeftToRight = p5.dx < p6.dx && p6.dx < p1.dx;

    return frontInFront && frontLeftToRight && backLeftToRight;
  }

  void _storeCurrentOffsetsAndPersist() {
    _savedOffsetsByRotation[_rotationIndex] = Map<int, Offset>.from(
      _currentOffsets,
    );
    _saveCurrentState();
  }

  void _rotate({required bool forward}) {
    _storeCurrentOffsetsAndPersist();

    final previous = List<int>.from(_playerAtPosition);
    for (var i = 0; i < _clockwiseCycle.length; i++) {
      final from = _clockwiseCycle[i];
      final to =
          _clockwiseCycle[(i + (forward ? 1 : -1) + _clockwiseCycle.length) %
              _clockwiseCycle.length];
      _playerAtPosition[to] = previous[from];
    }

    _rotationIndex = (_rotationIndex + (forward ? 1 : -1)) % 6;
    if (_rotationIndex < 0) {
      _rotationIndex += 6;
    }

    _ensureCurrentOffsets(_currentCourtSize);
    _saveCurrentState();
    setState(() {});
  }

  void _onDragUpdate({
    required int player,
    required DragUpdateDetails details,
  }) {
    final current = _currentOffsets[player] ?? Offset.zero;
    _currentOffsets[player] = _clampOffset(
      current + details.delta,
      _currentCourtSize,
    );
    setState(() {});
  }

  void _onDragEnd({required int player, required Offset previousOffset}) {
    if (!_isLegalByRotationRule(_currentOffsets)) {
      _currentOffsets[player] = previousOffset;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Invalid overlap with rotation rules. Keep 4-3-2 and 5-6-1 order, and front players in front of their pair.',
          ),
        ),
      );
      return;
    }

    _storeCurrentOffsetsAndPersist();
  }

  void _resetCurrentRotation() {
    if (_currentCourtSize == Size.zero) {
      return;
    }

    _currentOffsets
      ..clear()
      ..addAll(_defaultOffsets(_currentCourtSize));
    _activeOffsetsRotation = _rotationIndex;
    _offsetsCourtSize = _currentCourtSize;
    _savedOffsetsByRotation[_rotationIndex] = Map<int, Offset>.from(
      _currentOffsets,
    );
    _saveCurrentState();
    setState(() {});
  }

  Widget _buildRightGrid() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reference Positions',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _gridOrder.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.35,
                ),
                itemBuilder: (context, index) {
                  final position = _gridOrder[index];
                  final player = _playerAtPosition[position];
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Theme.of(context).colorScheme.secondaryContainer,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Pos $position'),
                          const SizedBox(height: 4),
                          Text(
                            widget.playerNames[player],
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftDraggable() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Position',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final courtSize = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    _currentCourtSize = courtSize;
                    _ensureCurrentOffsets(courtSize);

                    return Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: CourtGuidePainter(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ),
                        for (var position = 1; position <= 6; position++)
                          _buildDraggablePlayer(position: position),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraggablePlayer({required int position}) {
    final player = _playerAtPosition[position];
    final offset = _currentOffsets[player] ?? Offset.zero;
    final playerName = widget.playerNames[player].trim();
    final initial = playerName.isEmpty
        ? '?'
        : playerName.substring(0, 1).toUpperCase();

    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: GestureDetector(
        onPanStart: (_) {},
        onPanUpdate: (details) =>
            _onDragUpdate(player: player, details: details),
        onPanEnd: (_) {
          final current = _currentOffsets[player] ?? Offset.zero;
          final previous =
              _savedOffsetsByRotation[_rotationIndex]?[player] ?? current;
          _onDragEnd(player: player, previousOffset: previous);
        },
        child: SizedBox(
          width: _cardWidth,
          height: _cardHeight,
          child: Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            margin: EdgeInsets.zero,
            shape: const CircleBorder(),
            child: Center(
              child: Text(
                initial,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Rotation ${_rotationIndex + 1} of 6')),
      body: _isLoadingStorage
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final board = constraints.maxWidth < 760
                      ? Column(
                          children: [
                            Expanded(child: _buildLeftDraggable()),
                            const SizedBox(height: 12),
                            SizedBox(height: 280, child: _buildRightGrid()),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: _buildLeftDraggable()),
                            const SizedBox(width: 12),
                            Expanded(child: _buildRightGrid()),
                          ],
                        );

                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Expanded(child: board),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonalIcon(
                            onPressed: _resetCurrentRotation,
                            icon: const Icon(Icons.restart_alt),
                            label: const Text('Reset Current Rotation'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _rotate(forward: false),
                                icon: const Icon(Icons.rotate_left),
                                label: const Text('Backward Rotation'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => _rotate(forward: true),
                                icon: const Icon(Icons.rotate_right),
                                label: const Text('Forward Rotation'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class CourtGuidePainter extends CustomPainter {
  const CourtGuidePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final rowY = size.height * 0.5;
    final col1 = size.width / 3;
    final col2 = size.width * 2 / 3;

    canvas.drawRect(Offset.zero & size, paint);
    canvas.drawLine(Offset(0, rowY), Offset(size.width, rowY), paint);
    canvas.drawLine(Offset(col1, 0), Offset(col1, size.height), paint);
    canvas.drawLine(Offset(col2, 0), Offset(col2, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CourtGuidePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
