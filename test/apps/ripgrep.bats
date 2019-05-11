@test "ripgrep of recent version can be installed and uninstalled" {
  run sdd install ripgrep
  [ $status -eq 0 ]
  [[ "${lines[0]}" = 'Latest version available: '* ]]
  [ "${lines[1]}" = 'Installed "ripgrep".' ]

  run rg --version
  [ $status -eq 0 ]

  run sdd uninstall ripgrep
  [ $status -eq 0 ]
  [ "$output" = 'Uninstalled "ripgrep".' ]

  run which rg
  [ $status -eq 1 ]
}
