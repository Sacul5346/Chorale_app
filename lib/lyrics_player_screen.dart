import 'package:flutter/material.dart';

class LyricsPlayerScreen extends StatefulWidget {
  final String songId;
  final Map<String, dynamic> songData;

  const LyricsPlayerScreen({
    super.key,
    required this.songId,
    required this.songData,
  });

  @override
  State<LyricsPlayerScreen> createState() => _LyricsPlayerScreenState();
}

class _LyricsPlayerScreenState extends State<LyricsPlayerScreen> {
  bool _isPlaying = false;
  int _currentLyricLine = 0;
  late List<String> _lyricLines;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _lyricLines = (widget.songData['lyrics'] as String?)
            ?.split('\n')
            .where((line) => line.trim().isNotEmpty)
            .toList() ??
        [];
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
    });

    if (_isPlaying) {
      _simulatePlayback();
    }
  }

  void _simulatePlayback() {
    Future.delayed(const Duration(seconds: 3), () {
      if (_isPlaying && mounted) {
        setState(() {
          if (_currentLyricLine < _lyricLines.length - 1) {
            _currentLyricLine++;
            _scrollToCurrentLine();
          } else {
            _isPlaying = false;
            _currentLyricLine = 0;
          }
        });
        if (_isPlaying) {
          _simulatePlayback();
        }
      }
    });
  }

  void _scrollToCurrentLine() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _currentLyricLine * 40.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.songData['title'] ?? 'Sans titre'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // En-tête avec infos de la chanson
          Container(
            color: Colors.deepPurple.withValues(alpha: 0.1),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.music_note,
                  size: 48,
                  color: Colors.deepPurple,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.songData['title'] ?? 'Sans titre',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.songData['artist'] ?? 'Artiste inconnu',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          // Affichage des lyrics
          Expanded(
            child: _lyricLines.isEmpty
                ? Center(
                    child: Text(
                      'Aucun lyrics disponible',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _lyricLines.length,
                    itemBuilder: (context, index) {
                      final isCurrentLine = index == _currentLyricLine;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          _lyricLines[index],
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: isCurrentLine
                                    ? Colors.deepPurple
                                    : Colors.grey[600],
                                fontSize: isCurrentLine ? 18 : 16,
                                fontWeight: isCurrentLine
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                        ),
                      );
                    },
                  ),
          ),
          // Contrôles de lecture
          Container(
            color: Colors.deepPurple.withValues(alpha: 0.05),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Barre de progression
                LinearProgressIndicator(
                  value: _lyricLines.isEmpty
                      ? 0
                      : _currentLyricLine / _lyricLines.length,
                  minHeight: 4,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                ),
                const SizedBox(height: 16),
                // Boutons de contrôle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.first_page),
                      onPressed: () {
                        setState(() {
                          _currentLyricLine = 0;
                          _isPlaying = false;
                        });
                      },
                    ),
                    FloatingActionButton(
                      onPressed: _togglePlayPause,
                      backgroundColor: Colors.deepPurple,
                      child: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.last_page),
                      onPressed: () {
                        setState(() {
                          _currentLyricLine = _lyricLines.length - 1;
                          _isPlaying = false;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Ligne ${_currentLyricLine + 1} / ${_lyricLines.length}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
