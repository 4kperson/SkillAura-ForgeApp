import 'package:app_links/app_links.dart';

abstract interface class EmailConfirmationLinkSource {
  Future<Uri?> initialLink();

  Stream<Uri> get links;
}

class AppLinksEmailConfirmationLinkSource
    implements EmailConfirmationLinkSource {
  AppLinksEmailConfirmationLinkSource({AppLinks? appLinks})
    : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;

  @override
  Future<Uri?> initialLink() => _appLinks.getInitialLink();

  @override
  Stream<Uri> get links => _appLinks.uriLinkStream;
}
