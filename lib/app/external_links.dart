import 'package:url_launcher/url_launcher.dart';

final privacyPolicyUri = Uri.parse(
  'https://trip-planner-dby.pages.dev/privacy',
);

/// [theme] 是 `light`／`dark`（見 `resolveWebTheme`），讓 web 與 App 同明暗。
Uri privacyPolicyUriFor(String theme) =>
    privacyPolicyUri.replace(queryParameters: {'theme': theme});

Uri accountDeletionHelpUriFor(String theme) =>
    privacyPolicyUriFor(theme).replace(fragment: 'delete-account');

Future<void> openPrivacyPolicy(String theme) async {
  await launchUrl(
    privacyPolicyUriFor(theme),
    mode: LaunchMode.externalApplication,
  );
}

Future<void> openAccountDeletionHelp(String theme) async {
  await launchUrl(
    accountDeletionHelpUriFor(theme),
    mode: LaunchMode.externalApplication,
  );
}
