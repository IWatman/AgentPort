/// A release download handed to the Android download manager.
///
/// The metadata is persisted so an interrupted app session can reconnect to a
/// download that is still running in the background.
class PendingUpdateDownload {
  const PendingUpdateDownload({
    required this.id,
    required this.version,
    required this.fileName,
    this.checksumUrl,
  });

  final int id;
  final String version;
  final String fileName;
  final String? checksumUrl;
}
