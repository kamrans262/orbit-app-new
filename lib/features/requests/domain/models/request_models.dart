enum RequestViewState { loading, loaded, error }

class RequestData {
  const RequestData({
    required this.id,
    required this.name,
    required this.supportingText,
    this.imagePath,
  });

  final String id;
  final String name;
  final String supportingText;
  final String? imagePath;
}
