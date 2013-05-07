Feature: The script can be run

  Scenario: Run with basic options

    When I run the following:
      """
      hq-mongodb-check-collection-size
        --total-warning 2g
        --total-critical 10g
        --unsharded-warning 500m
        --unsharded-critical 1g
        --efficiency-warning 0.8
        --efficiency-critical 0.5
        --efficiency-size 100m
      """

    Then the exit status should be 0
    And the output should match:
      """
      MongoDB collection size OK: biggest is (.+)
      """
