/// The outcome of one doctor check.
enum CheckStatus {
  /// The check passed.
  pass,

  /// Information the developer needs, such as a fingerprint to register.
  info,

  /// Probably a problem, but it could not be confirmed.
  warning,

  /// A definite problem that breaks TikTok Login.
  error,
}

/// One line of the doctor report.
class CheckResult {
  /// Creates a result.
  const CheckResult(this.status, this.message, {this.fix});

  /// The outcome.
  final CheckStatus status;

  /// What was checked or found.
  final String message;

  /// How to fix the problem, if there is one.
  final String? fix;
}

/// Collects check results in titled sections and renders them as text.
class DoctorReport {
  final List<(String, List<CheckResult>)> _sections = [];

  /// Starts a new section called [title].
  void section(String title) => _sections.add((title, <CheckResult>[]));

  /// Records a passed check.
  void pass(String message) => _add(CheckResult(CheckStatus.pass, message));

  /// Records information.
  void info(String message) => _add(CheckResult(CheckStatus.info, message));

  /// Records a possible problem.
  void warning(String message, {String? fix}) =>
      _add(CheckResult(CheckStatus.warning, message, fix: fix));

  /// Records a definite problem.
  void error(String message, {String? fix}) =>
      _add(CheckResult(CheckStatus.error, message, fix: fix));

  /// Every recorded result, in order.
  Iterable<CheckResult> get results =>
      _sections.expand((section) => section.$2);

  /// The number of errors.
  int get errorCount =>
      results.where((result) => result.status == CheckStatus.error).length;

  /// The number of warnings.
  int get warningCount =>
      results.where((result) => result.status == CheckStatus.warning).length;

  /// Renders the report, using ANSI colors if [color] is true.
  String render({bool color = false}) {
    String paint(String text, String code) =>
        color ? '\x1B[${code}m$text\x1B[0m' : text;

    final buffer = StringBuffer();
    for (final (title, results) in _sections) {
      if (results.isEmpty) continue;
      buffer
        ..writeln()
        ..writeln(paint(title, '1'));
      for (final result in results) {
        final symbol = switch (result.status) {
          CheckStatus.pass => paint('✓', '32'),
          CheckStatus.info => paint('•', '36'),
          CheckStatus.warning => paint('!', '33'),
          CheckStatus.error => paint('✗', '31'),
        };
        final lines = result.message.split('\n');
        buffer.writeln('  $symbol ${lines.first}');
        for (final line in lines.skip(1)) {
          buffer.writeln('    $line');
        }
        final fix = result.fix;
        if (fix != null) {
          final fixLines = fix.split('\n');
          buffer.writeln('    ${paint('Fix:', '1')} ${fixLines.first}');
          for (final line in fixLines.skip(1)) {
            buffer.writeln('         $line');
          }
        }
      }
    }
    buffer
      ..writeln()
      ..writeln(
        errorCount == 0 && warningCount == 0
            ? paint('No problems found.', '32')
            : '$errorCount error${errorCount == 1 ? '' : 's'}, '
                  '$warningCount warning${warningCount == 1 ? '' : 's'}.',
      );
    return buffer.toString();
  }

  void _add(CheckResult result) {
    if (_sections.isEmpty) section('Checks');
    _sections.last.$2.add(result);
  }
}
