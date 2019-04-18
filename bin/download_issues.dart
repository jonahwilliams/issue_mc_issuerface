// Copyright 2019 Jonah Williams. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as path;

/// The Github issue API.
const issueApi = 'https://api.github.com/repos/flutter/flutter/issues';

final argParser = ArgParser()
  ..addOption('output', help: 'the directory to write issues to.');

/// A script for downloading the issues for the flutter repo.
///
/// Will output each page of issues individually as JSON to the specified
/// output directory.
///
/// To avoid rate-limiting, an authentication token should be provided via the
/// environment variable `GITHUB_SECRET`.
void main(List<String> args) async {
  // Parse output directory, and create if it doesn't exist.
  var argResults = argParser.parse(args);
  var outputDirectory = Directory(argResults['output']);
  if (!outputDirectory.existsSync()) {
    outputDirectory.createSync(recursive: true);
  }
  // Initialize http client.
  var client = HttpClient();
  var page = 0;
  // Request issues until there is a failure or on the first empty response.
  while (true) {
    var request = await client.getUrl(Uri.parse('$issueApi?page=$page'));
    request.headers.set(
      HttpHeaders.authorizationHeader,
      Platform.environment['GITHUB_SECRET'],
    );
    var response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      break;
    }
    var body = await response.transform(utf8.decoder).join('');
    var issues = json.decode(body) as List<dynamic>;
    if (issues.isEmpty) {
      // We've reached the end of the line.
      break;
    }
    // Remove pull requests.
    issues.removeWhere((dynamic issue) {
      return issue['pull_request'] != null;
    });
    // Create output file.
    File(path.join(outputDirectory.path, 'issues_$page.json'))
      ..createSync()
      ..writeAsStringSync(json.encode(issues));
    page += 1;
  }
  exit(0);
}
