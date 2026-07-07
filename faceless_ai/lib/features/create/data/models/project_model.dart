import 'package:equatable/equatable.dart';

/// Project model — maps to the Supabase `projects` table
class ProjectModel extends Equatable {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final String tone;
  final ProjectStatus status;

  // Input
  final String? userMediaUrl;
  final String productName;
  final String productDescription;

  // Generated
  final Map<String, dynamic>? scriptJson;
  final Map<String, dynamic>? renderSpecJson;

  // Output
  final String? videoUrl;
  final String? thumbnailUrl;
  final int? durationSec;

  // Progress
  final int renderProgress;
  final String? errorMessage;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProjectModel({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.tone = 'inspirational',
    this.status = ProjectStatus.draft,
    this.userMediaUrl,
    required this.productName,
    required this.productDescription,
    this.scriptJson,
    this.renderSpecJson,
    this.videoUrl,
    this.thumbnailUrl,
    this.durationSec,
    this.renderProgress = 0,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      tone: json['tone'] as String? ?? 'inspirational',
      status: ProjectStatus.fromString(json['status'] as String? ?? 'draft'),
      userMediaUrl: json['user_media_url'] as String?,
      productName: json['product_name'] as String? ?? '',
      productDescription: json['product_description'] as String? ?? '',
      scriptJson: json['script_json'] as Map<String, dynamic>?,
      renderSpecJson: json['render_spec_json'] as Map<String, dynamic>?,
      videoUrl: json['video_url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      durationSec: json['duration_sec'] as int?,
      renderProgress: json['render_progress'] as int? ?? 0,
      errorMessage: json['error_message'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'title': title,
        'user_id': userId,
        'description': description,
        'tone': tone,
        'status': status.value,
        'user_media_url': userMediaUrl,
        'product_name': productName,
        'product_description': productDescription,
      };

  ProjectModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    String? tone,
    ProjectStatus? status,
    String? userMediaUrl,
    String? productName,
    String? productDescription,
    Map<String, dynamic>? scriptJson,
    Map<String, dynamic>? renderSpecJson,
    String? videoUrl,
    String? thumbnailUrl,
    int? durationSec,
    int? renderProgress,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      tone: tone ?? this.tone,
      status: status ?? this.status,
      userMediaUrl: userMediaUrl ?? this.userMediaUrl,
      productName: productName ?? this.productName,
      productDescription: productDescription ?? this.productDescription,
      scriptJson: scriptJson ?? this.scriptJson,
      renderSpecJson: renderSpecJson ?? this.renderSpecJson,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      durationSec: durationSec ?? this.durationSec,
      renderProgress: renderProgress ?? this.renderProgress,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id, userId, title, status, productName,
        renderProgress, videoUrl, updatedAt,
      ];
}

/// Project lifecycle status
enum ProjectStatus {
  draft('draft'),
  scripting('scripting'),
  fetching('fetching'),
  rendering('rendering'),
  completed('completed'),
  failed('failed');

  final String value;
  const ProjectStatus(this.value);

  factory ProjectStatus.fromString(String value) {
    return ProjectStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => ProjectStatus.draft,
    );
  }

  bool get isProcessing =>
      this == scripting || this == fetching || this == rendering;

  String get displayLabel {
    switch (this) {
      case draft:
        return 'Draft';
      case scripting:
        return 'Writing Script...';
      case fetching:
        return 'Gathering Assets...';
      case rendering:
        return 'Rendering Video...';
      case completed:
        return 'Ready';
      case failed:
        return 'Failed';
    }
  }
}
