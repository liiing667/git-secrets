#!/usr/bin/env bats
load test_helper

@test "Rejects commits with prohibited patterns in changeset" {
  setup_bad_repo
  repo_run git-secrets --install $TEST_REPO
  cd $TEST_REPO
  run git commit -m 'Contents are bad not the message'
  [ $status -eq 1 ]
  [ "${lines[0]}" == "data.txt:1:@todo more stuff" ]
  [ "${lines[1]}" == "failure1.txt:1:another line... forbidden" ]
  [ "${lines[2]}" == "failure2.txt:1:me" ]
}

@test "Rejects commits with prohibited patterns in changeset with filename that contain spaces" {
  setup_bad_repo_with_spaces
  repo_run git-secrets --install $TEST_REPO
  cd $TEST_REPO
  run git commit -m 'Contents are bad not the message'
  [ $status -eq 1 ]
  [ "${lines[0]}" == "da ta.txt:1:@todo more stuff" ]
}

@test "Rejects commits with prohibited patterns in a file whose name starts with -e" {
  cd $TEST_REPO
  repo_run git-secrets --install $TEST_REPO
  # A leading "-e" would be parsed as a grep option without a "--" separator.
  echo '@todo more stuff' > "$TEST_REPO/-eevil.txt"
  git add -A
  cd $TEST_REPO
  run git commit -m 'Contents are bad not the message'
  [ $status -eq 1 ]
  echo "$output" | grep -F -- '-eevil.txt:1:@todo more stuff'
}

@test "Rejects commits with prohibited patterns in a file whose name starts with --exclude" {
  cd $TEST_REPO
  repo_run git-secrets --install $TEST_REPO
  # grep would silently skip this path if it were interpreted as --exclude.
  echo '@todo more stuff' > "$TEST_REPO/--exclude=.*"
  git add -A
  cd $TEST_REPO
  run git commit -m 'Contents are bad not the message'
  [ $status -eq 1 ]
  echo "$output" | grep -F -- '--exclude=.*:1:@todo more stuff'
}

@test "Rejects commits with prohibited patterns in a file whose name contains a newline" {
  cd $TEST_REPO
  repo_run git-secrets --install $TEST_REPO
  # A newline in the name must not split it into two (non-existent) paths.
  echo '@todo more stuff' > "$(printf '%s/bad\nname.txt' "$TEST_REPO")"
  git add -A
  cd $TEST_REPO
  run git commit -m 'Contents are bad not the message'
  [ $status -eq 1 ]
  echo "$output" | grep -F -- '"bad\nname.txt":1:@todo more stuff'
}

@test "Allows clean commits when a staged file name starts with -e" {
  cd $TEST_REPO
  repo_run git-secrets --install $TEST_REPO
  echo 'nothing suspicious here' > "$TEST_REPO/-eevil.txt"
  git add -A
  cd $TEST_REPO
  run git commit -m 'Contents are clean'
  [ $status -eq 0 ]
}

@test "Scans staged files" {
  cd $TEST_REPO
  repo_run git-secrets --install $TEST_REPO
  echo '@todo more stuff' > $TEST_REPO/data.txt
  echo 'hi there' > $TEST_REPO/ok.txt
  git add -A
  echo 'fixed the working directory, but not staged' > $TEST_REPO/data.txt
  run git commit -m 'Contents are bad not the message'
  [ $status -eq 1 ]
  [ "${lines[0]}" == "data.txt:1:@todo more stuff" ]
}

@test "Allows commits that do not match prohibited patterns" {
  setup_good_repo
  repo_run git-secrets --install $TEST_REPO
  cd $TEST_REPO
  run git commit -m 'This is fine'
  [ $status -eq 0 ]
  # Ensure deleted files are filtered out of the grep
  rm $TEST_REPO/data.txt
  echo 'aaa' > $TEST_REPO/data_2.txt
  run git add -A
  run git commit -m 'This is also fine'
  [ $status -eq 0 ]
}

@test "Rejects commits with prohibited patterns in changeset when AWS provider is enabled" {
  setup_bad_repo
  repo_run git-secrets --install $TEST_REPO
  repo_run git-secrets --register-aws $TEST_REPO
  cd $TEST_REPO
  run git commit -m 'Contents are bad not the message'
  [ $status -eq 1 ]
  echo "${lines}" | grep -vq 'git secrets --aws-provider: command not found'

  [ "${lines[0]}" == "data.txt:1:@todo more stuff" ]
  [ "${lines[1]}" == "failure1.txt:1:another line... forbidden" ]
  [ "${lines[2]}" == "failure2.txt:1:me" ]
}
