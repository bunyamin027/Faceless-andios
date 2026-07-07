import 'package:equatable/equatable.dart';

/// A single scene in the AI-generated script
class SceneModel extends Equatable {
  final int sceneNumber;
  final int durationSec;
  final String voiceoverText;
  final String displayText;
  final String textAnimation; // 'pop_word' | 'karaoke_highlight' | 'fade_in'
  final List<String> brollKeywords;
  final bool showMockup;

  // Populated after asset fetching
  final String? brollUrl;
  final String? brollThumbnail;

  const SceneModel({
    required this.sceneNumber,
    required this.durationSec,
    required this.voiceoverText,
    required this.displayText,
    required this.textAnimation,
    required this.brollKeywords,
    required this.showMockup,
    this.brollUrl,
    this.brollThumbnail,
  });

  factory SceneModel.fromJson(Map<String, dynamic> json) {
    return SceneModel(
      sceneNumber: json['scene_number'] as int,
      durationSec: json['duration_sec'] as int,
      voiceoverText: json['voiceover_text'] as String,
      displayText: json['display_text'] as String,
      textAnimation: json['text_animation'] as String? ?? 'pop_word',
      brollKeywords: List<String>.from(json['broll_keywords'] ?? []),
      showMockup: json['show_mockup'] as bool? ?? false,
      brollUrl: json['broll_url'] as String?,
      brollThumbnail: json['broll_thumbnail'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'scene_number': sceneNumber,
        'duration_sec': durationSec,
        'voiceover_text': voiceoverText,
        'display_text': displayText,
        'text_animation': textAnimation,
        'broll_keywords': brollKeywords,
        'show_mockup': showMockup,
        'broll_url': brollUrl,
        'broll_thumbnail': brollThumbnail,
      };

  SceneModel copyWith({
    int? sceneNumber,
    int? durationSec,
    String? voiceoverText,
    String? displayText,
    String? textAnimation,
    List<String>? brollKeywords,
    bool? showMockup,
    String? brollUrl,
    String? brollThumbnail,
  }) {
    return SceneModel(
      sceneNumber: sceneNumber ?? this.sceneNumber,
      durationSec: durationSec ?? this.durationSec,
      voiceoverText: voiceoverText ?? this.voiceoverText,
      displayText: displayText ?? this.displayText,
      textAnimation: textAnimation ?? this.textAnimation,
      brollKeywords: brollKeywords ?? this.brollKeywords,
      showMockup: showMockup ?? this.showMockup,
      brollUrl: brollUrl ?? this.brollUrl,
      brollThumbnail: brollThumbnail ?? this.brollThumbnail,
    );
  }

  @override
  List<Object?> get props => [
        sceneNumber,
        durationSec,
        voiceoverText,
        displayText,
        textAnimation,
        brollKeywords,
        showMockup,
        brollUrl,
        brollThumbnail,
      ];
}

/// Full script output from Gemini
class ScriptModel extends Equatable {
  final String title;
  final List<SceneModel> scenes;
  final int totalDurationSec;
  final String musicMood;

  const ScriptModel({
    required this.title,
    required this.scenes,
    required this.totalDurationSec,
    required this.musicMood,
  });

  factory ScriptModel.fromJson(Map<String, dynamic> json) {
    return ScriptModel(
      title: json['title'] as String,
      scenes: (json['scenes'] as List)
          .map((s) => SceneModel.fromJson(s as Map<String, dynamic>))
          .toList(),
      totalDurationSec: json['total_duration_sec'] as int,
      musicMood: json['music_mood'] as String? ?? 'ambient_calm',
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'scenes': scenes.map((s) => s.toJson()).toList(),
        'total_duration_sec': totalDurationSec,
        'music_mood': musicMood,
      };

  @override
  List<Object?> get props => [title, scenes, totalDurationSec, musicMood];
}
