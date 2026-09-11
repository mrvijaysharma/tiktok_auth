/// Parses an XML property list, such as `Info.plist` or a `.entitlements`
/// file.
///
/// Returns the root value: a `Map<String, Object?>`, `List<Object?>`,
/// `String`, `int`, `double` or `bool`. Throws a [FormatException] if
/// [source] is not a well-formed XML property list.
Object? parsePlist(String source) => _PlistParser(source).parse();

enum _Kind { open, close, empty, text }

class _Token {
  const _Token(this.kind, this.value);

  final _Kind kind;
  final String value;

  bool isOpen(String name) => kind == _Kind.open && value == name;

  bool isClose(String name) => kind == _Kind.close && value == name;

  @override
  String toString() => switch (kind) {
    _Kind.open => '<$value>',
    _Kind.close => '</$value>',
    _Kind.empty => '<$value/>',
    _Kind.text => 'text "$value"',
  };
}

class _PlistParser {
  _PlistParser(String source) : _tokens = _tokenize(source);

  static final _tag = RegExp('<(/?)([A-Za-z]+)[^>]*?(/?)>');

  final List<_Token> _tokens;
  var _index = 0;

  Object? parse() {
    final first = _next();
    if (first.isOpen('plist')) {
      final value = _value(_next());
      _expectClose('plist');
      return value;
    }
    return _value(first);
  }

  Object? _value(_Token token) {
    if (token.kind == _Kind.empty) {
      return switch (token.value) {
        'true' => true,
        'false' => false,
        'dict' => <String, Object?>{},
        'array' => <Object?>[],
        'string' => '',
        _ => throw FormatException('Unexpected $token'),
      };
    }
    if (token.kind != _Kind.open) {
      throw FormatException('Expected a value, found $token');
    }
    switch (token.value) {
      case 'dict':
        final map = <String, Object?>{};
        while (true) {
          final next = _next();
          if (next.isClose('dict')) return map;
          if (!next.isOpen('key')) {
            throw FormatException('Expected <key> in <dict>, found $next');
          }
          final key = _text('key');
          map[key] = _value(_next());
        }
      case 'array':
        final list = <Object?>[];
        while (!_peek().isClose('array')) {
          list.add(_value(_next()));
        }
        _next();
        return list;
      case 'string' || 'date' || 'data':
        return _text(token.value);
      case 'integer':
        return int.parse(_text('integer').trim());
      case 'real':
        return double.parse(_text('real').trim());
      case 'true':
        _expectClose('true');
        return true;
      case 'false':
        _expectClose('false');
        return false;
      default:
        throw FormatException('Unsupported element <${token.value}>');
    }
  }

  String _text(String element) {
    final next = _next();
    if (next.isClose(element)) return '';
    if (next.kind != _Kind.text) {
      throw FormatException('Expected text in <$element>, found $next');
    }
    _expectClose(element);
    return next.value;
  }

  void _expectClose(String element) {
    final next = _next();
    if (!next.isClose(element)) {
      throw FormatException('Expected </$element>, found $next');
    }
  }

  _Token _peek() {
    if (_index >= _tokens.length) {
      throw const FormatException('Unexpected end of property list');
    }
    return _tokens[_index];
  }

  _Token _next() {
    final token = _peek();
    _index++;
    return token;
  }

  static List<_Token> _tokenize(String source) {
    final cleaned = source
        .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '')
        .replaceAll(RegExp(r'<\?[\s\S]*?\?>'), '')
        .replaceAll(RegExp(r'<!DOCTYPE[\s\S]*?>'), '');
    final tokens = <_Token>[];
    var index = 0;
    for (final match in _tag.allMatches(cleaned)) {
      if (match.start > index) {
        final text = cleaned.substring(index, match.start);
        if (text.trim().isNotEmpty) {
          tokens.add(_Token(_Kind.text, _decodeEntities(text)));
        }
      }
      final name = match.group(2)!;
      final kind = match.group(1) == '/'
          ? _Kind.close
          : match.group(3) == '/'
          ? _Kind.empty
          : _Kind.open;
      tokens.add(_Token(kind, name));
      index = match.end;
    }
    return tokens;
  }

  static String _decodeEntities(String text) => text
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');
}
