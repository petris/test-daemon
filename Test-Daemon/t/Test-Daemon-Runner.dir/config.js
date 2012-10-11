{
"Test::Daemon::Runner": {
	"testsets": {
		"default": {
			"root":     "${TESTD_CONFIG_DIR}tests/",
			"run":      [".*\\.pl"],
			"get_info": "Test::Daemon::Deployment::Exec::get_info"
		}
	},
	"provided_resources": {
		"First_World_Resource": {
			"provides":  ["world_resource"],
			"variables": {"id": 1}
		},
		"Second_World_Resource": {
			"provides":  ["world_resource"],
			"variables": {"id": 2}
		}
	},
	"environments": {
		"default": {
			"provided_resources": {
				"env_running_tc_1": {
					"provides": ["running_testcase"],
					"variables": {"id": 1}
				},
				"env_running_tc_2": {
					"provides": ["running_testcase"],
					"variables": {"id": 2}
				}
			},
			"exclusive_resources": {
				"world": ["world_resource"]
			},
			"deployments": [
				["Test::Daemon::Deployment::Exec", {
				}]
			]
		},
		"double": {
			"provided_resources": {
				"env_running_tc_3": {
					"provides": ["running_testcase"],
					"variables": {"id": 3}
				}
			},
			"exclusive_resources": {
				"first_world": ["world_resource"],
				"second_world": ["world_resource"]
			},
			"deployments": [
				["Test::Daemon::Deployment::Exec", {
				}]
			]
		}
	}
}
}
