import 'package:flutter/material.dart';
import 'dart:math';

void main() {
  runApp(const DollarSortingGame());
}

class DollarSortingGame extends StatelessWidget {
  const DollarSortingGame({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dollar Sorting Game',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const GamePage(),
    );
  }
}

/// Represents a stack of bills of the same denomination.
class BillStack {
  int denomination;
  int count;
  Offset offset; // Visual offset for "messy" stacking within a tray

  BillStack({required this.denomination, required this.count, required this.offset});
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  // 10 trays, each can hold multiple stacks of bills. Max 3 stacks per tray.
  final List<List<BillStack>> _trays = List.generate(10, (_) => []);

  // Merge rules: 5x$1 -> $5, 4x$5 -> $20, 5x$20 -> $100
  final Map<int, int> _mergeThresholds = {1: 5, 5: 4, 20: 5};
  final Map<int, int> _nextDenom = {1: 5, 5: 20, 20: 100};

  final Random _random = Random();

  /// Adds 5 x $1 bills to a random tray.
  /// Lands them as individual items (count: 1) stacked on top of whatever is there.
  void _addBills() {
    setState(() {
      int targetIndex = _random.nextInt(10);
      
      // Add the 5 x $1 bills as individual stacks
      for (int i = 0; i < 5; i++) {
        _trays[targetIndex].add(BillStack(
          denomination: 1, 
          count: 1,
          offset: Offset(_random.nextDouble() * 30 - 15, _random.nextDouble() * 30 - 15),
        ));
      }
    });
  }

  /// Handles dropping a stack into the general tray area (moving it).
  /// If the top bill of the target tray matches and follows stacking rules, they automatically combine.
  void _onTrayDrop(int targetTrayIndex, Map<String, dynamic> data) {
    setState(() {
      int sourceTrayIndex = data['fromTray'];
      int sourceStackIndex = data['stackIndex'];
      int denom = data['denom'];
      int count = data['count'];

      final targetTray = _trays[targetTrayIndex];

      // AUTOMATIC MATCHING with TOP bill if it matches and foundation is pure.
      if (targetTray.isNotEmpty) {
        int topIndex = targetTray.length - 1;
        
        // Ensure we are not matching a stack with itself
        if (!(sourceTrayIndex == targetTrayIndex && sourceStackIndex == topIndex)) {
          final topStack = targetTray.last;
          
          if (topStack.denomination == denom) {
            // Rule: Combine ONLY if everything below it in the tray also matches this denomination.
            bool chainMatches = true;
            for (int i = 0; i < topIndex; i++) {
              if (targetTray[i].denomination != denom) {
                chainMatches = false;
                break;
              }
            }

            if (chainMatches) {
              topStack.count += count;
              _trays[sourceTrayIndex].removeAt(sourceStackIndex);
              _checkMerge(targetTrayIndex, targetTray.length - 1);
              return;
            }
          }
        } else {
          // Dropped on itself - update offset
          targetTray[sourceStackIndex].offset = Offset(_random.nextDouble() * 30 - 15, _random.nextDouble() * 30 - 15);
          return;
        }
      }

      // If no merge, check tray capacity
      if (sourceTrayIndex != targetTrayIndex && targetTray.length >= 10) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This tray is full (max 3 stacks)!')),
        );
        return;
      }

      // Move stack
      final stack = _trays[sourceTrayIndex].removeAt(sourceStackIndex);
      stack.offset = Offset(_random.nextDouble() * 30 - 15, _random.nextDouble() * 30 - 15);
      _trays[targetTrayIndex].add(stack);
    });
  }

  /// Handles dropping a stack ON another stack.
  void _onStackDrop(int targetTrayIndex, int targetStackIndex, Map<String, dynamic> data) {
    setState(() {
      int sourceTrayIndex = data['fromTray'];
      int sourceStackIndex = data['stackIndex'];
      int denom = data['denom'];
      int count = data['count'];

      if (sourceTrayIndex == targetTrayIndex && sourceStackIndex == targetStackIndex) return;

      final tray = _trays[targetTrayIndex];
      final targetStack = tray[targetStackIndex];

      // Logic: Only combine if target matches AND everything below it in the tray also matches.
      bool chainMatches = true;
      for (int i = 0; i <= targetStackIndex; i++) {
        if (tray[i].denomination != denom) {
          chainMatches = false;
          break;
        }
      }

      if (chainMatches) {
        targetStack.count += count;
        _trays[sourceTrayIndex].removeAt(sourceStackIndex);
        
        int indexToCheck = targetStackIndex;
        if (sourceTrayIndex == targetTrayIndex && sourceStackIndex < targetStackIndex) {
          indexToCheck--;
        }
        
        _checkMerge(targetTrayIndex, indexToCheck);
      } else {
        _onTrayDrop(targetTrayIndex, data);
      }
    });
  }

  /// Core merge logic: 5x$1 -> 1x$5 etc.
  void _checkMerge(int trayIndex, int stackIndex) {
    if (stackIndex < 0 || stackIndex >= _trays[trayIndex].length) return;
    
    final stack = _trays[trayIndex][stackIndex];
    final threshold = _mergeThresholds[stack.denomination];
    
    if (threshold != null && stack.count >= threshold) {
      int oldDenom = stack.denomination;
      int nextValue = _nextDenom[oldDenom]!;
      int mergedCount = stack.count ~/ threshold;
      int remainder = stack.count % threshold;

      stack.denomination = nextValue;
      stack.count = mergedCount;

      if (remainder > 0) {
        _placeRemainder(trayIndex, oldDenom, remainder);
      }
      
      _consolidateTray(trayIndex);
    }
  }

  /// Places a merge remainder into a tray that has space.
  void _placeRemainder(int preferredTrayIndex, int denom, int count) {
    if (_trays[preferredTrayIndex].length < 3) {
      _trays[preferredTrayIndex].add(BillStack(
        denomination: denom, 
        count: count,
        offset: Offset(_random.nextDouble() * 30 - 15, _random.nextDouble() * 30 - 15),
      ));
    } else {
      for (int i = 0; i < 10; i++) {
        if (_trays[i].length < 3) {
          _trays[i].add(BillStack(
            denomination: denom, 
            count: count,
            offset: Offset(_random.nextDouble() * 30 - 15, _random.nextDouble() * 30 - 15),
          ));
          return;
        }
      }
    }
  }

  /// Combines adjacent stacks of the same denomination within a tray if they exist and follow stacking rules.
  void _consolidateTray(int trayIndex) {
    final tray = _trays[trayIndex];
    for (int i = 0; i < tray.length - 1; i++) {
      if (tray[i].denomination == tray[i + 1].denomination) {
        // Only combine if the foundation is pure
        bool pure = true;
        for (int k = 0; k <= i; k++) {
          if (tray[k].denomination != tray[i].denomination) {
            pure = false;
            break;
          }
        }
        if (pure) {
          tray[i].count += tray[i + 1].count;
          tray.removeAt(i + 1);
          _checkMerge(trayIndex, i);
          return;
        }
      }
    }
  }

  /// Calculates total value. Only bills that match everything below them in their tray count.
  int _calculateTotal() {
    int total = 0;
    for (var tray in _trays) {
      if (tray.isEmpty) continue;
      int baseDenom = tray[0].denomination;
      for (var stack in tray) {
        if (stack.denomination == baseDenom) {
          total += stack.denomination * stack.count;
        } else {
          break; // Stop at first mismatch from bottom
        }
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Dollar Sorting Game'),
        centerTitle: true,
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: Column(
        children: [
          // Total Wallet Summary
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Total Wallet Value', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text(
                      '\$${_calculateTotal()}',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('TRAYS (Combine identical bills to merge)', 
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1)),
          ),

          // Trays Grid Area: 2 rows of 5
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemCount: 10,
                itemBuilder: (context, index) => _buildTray(index),
              ),
            ),
          ),

          // Action Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: SizedBox(
              width: double.infinity,
              height: 70,
              child: ElevatedButton.icon(
                onPressed: _addBills,
                icon: const Icon(Icons.add_circle, size: 32),
                label: const Text('Add 5 x \$1 Bills', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTray(int trayIndex) {
    final stacks = _trays[trayIndex];

    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) => _onTrayDrop(trayIndex, details.data),
      builder: (context, candidateData, rejectedData) {
        bool isHovered = candidateData.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: isHovered ? Colors.green.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHovered ? Colors.green : Colors.grey.shade300,
              width: isHovered ? 2.5 : 1.5,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (stacks.isEmpty)
                const Center(child: Icon(Icons.inbox_outlined, color: Colors.black12, size: 28)),
              Positioned.fill(child: Container(color: Colors.transparent)),
              ...stacks.asMap().entries.map((entry) {
                return Positioned(
                  left: 4 + entry.value.offset.dx,
                  top: 4 + entry.value.offset.dy,
                  child: _buildDraggableStack(entry.value, trayIndex, entry.key),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDraggableStack(BillStack stack, int trayIndex, int stackIndex) {
    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) => _onStackDrop(trayIndex, stackIndex, details.data),
      builder: (context, candidateData, rejectedData) {
        bool isStackHovered = candidateData.isNotEmpty;
        return Draggable<Map<String, dynamic>>(
          data: {
            'denom': stack.denomination, 
            'fromTray': trayIndex, 
            'stackIndex': stackIndex,
            'count': stack.count
          },
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(opacity: 0.8, child: _buildBillWidget(stack.denomination, count: stack.count, isLarge: true)),
          ),
          childWhenDragging: const SizedBox.shrink(),
          child: Container(
            decoration: isStackHovered ? BoxDecoration(
              border: Border.all(color: Colors.green, width: 2),
              borderRadius: BorderRadius.circular(8),
            ) : null,
            child: _buildBillWidget(stack.denomination, count: stack.count),
          ),
        );
      },
    );
  }

  Widget _buildBillWidget(int denom, {required int count, bool isLarge = false}) {
    Color color;
    switch (denom) {
      case 1: color = Colors.green[600]!; break;
      case 5: color = Colors.blue[600]!; break;
      case 20: color = Colors.deepOrange[600]!; break;
      case 100: color = Colors.amber[800]!; break;
      default: color = Colors.grey;
    }

    return Container(
      width: isLarge ? 80 : 45,
      height: isLarge ? 50 : 30,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 4,
            offset: const Offset(1, 2),
          )
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '\$$denom',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: isLarge ? 14 : 10,
                decoration: TextDecoration.none,
              ),
            ),
            Text(
              'x$count',
              style: TextStyle(
                color: Colors.white70, 
                fontSize: isLarge ? 10 : 8, 
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
