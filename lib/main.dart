import 'package:flutter/material.dart';

import 'animated_card_stack.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AnimatedCardStack Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
      ),
      home: const CardStackDemo(),
    );
  }
}

class CardStackDemo extends StatefulWidget {
  const CardStackDemo({super.key});

  @override
  State<CardStackDemo> createState() => _CardStackDemoState();
}

class _CardStackDemoState extends State<CardStackDemo> {
  bool _enableShadows = true;
  final AnimatedCardStackController _controller = AnimatedCardStackController();
  final Set<int> _likedCards = {};
  CardData? _currentTopCard;

  @override
  void initState() {
    super.initState();
    _currentTopCard = _cards.isNotEmpty ? _cards[0] : null;
  }

  // Colorful gradient data for demo cards
  final List<CardData> _cards = [
    CardData(
      index: 1,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
      ),
      title: 'Card One',
    ),
    CardData(
      index: 2,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
      ),
      title: 'Card Two',
    ),
    CardData(
      index: 3,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
      ),
      title: 'Card Three',
    ),
    CardData(
      index: 4,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF43e97b), Color(0xFF38f9d7)],
      ),
      title: 'Card Four',
    ),
    CardData(
      index: 5,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFfa709a), Color(0xFFfee140)],
      ),
      title: 'Card Five',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('AnimatedCardStack', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          // Shadow toggle
          Row(
            children: [
              const Text('Shadows', style: TextStyle(fontSize: 14)),
              Switch(
                value: _enableShadows,
                onChanged: (value) {
                  setState(() {
                    _enableShadows = value;
                  });
                },
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedCardStack<CardData>(
              visibleCardCount: 5,
              items: _cards,
              controller: _controller,
              enableShadows: _enableShadows,
              cardWidth: 280,
              cardHeight: 380,
              dragThreshold: 80,
              reboundScale: 1,
              onTap: (card) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(card.title),
                    content: Text('You tapped ${card.title} (Card #${card.index})'),
                    actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
                  ),
                );
              },
              onCardChanged: (index, card) {
                // You could update state, log analytics, etc.
                // debugPrint('New top card: ${card.title} at index $index');
                setState(() {
                  _currentTopCard = card;
                });
              },
              onDoubleTap: (card) {
                setState(() {
                  if (_likedCards.contains(card.index)) {
                    _likedCards.remove(card.index);
                  } else {
                    _likedCards.add(card.index);
                  }
                });
              },
              itemBuilder: (context, card) => _buildCard(card),
            ),
            const SizedBox(height: 24),
            // Like Heart Icon
            if (_currentTopCard != null)
              Icon(
                _likedCards.contains(_currentTopCard!.index) ? Icons.favorite : Icons.favorite_border,
                color: _likedCards.contains(_currentTopCard!.index) ? Colors.red : Colors.white,
                size: 48,
              ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _controller.swipeNext(),
              icon: const Icon(Icons.skip_next),
              label: const Text('Next'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Swipe a card or tap Next to cycle',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(CardData card) {
    return Container(
      decoration: BoxDecoration(gradient: card.gradient, borderRadius: BorderRadius.circular(16)),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '#${card.index}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const Spacer(),
                Text(
                  card.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Drag me and release to send to back',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CardData {
  final int index;
  final Gradient gradient;
  final String title;

  CardData({required this.index, required this.gradient, required this.title});
}
