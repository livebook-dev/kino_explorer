defmodule KinoExplorer.DataTransformCellTest do
  use ExUnit.Case, async: true

  import Kino.Test

  alias KinoExplorer.DataTransformCell

  setup :configure_livebook_bridge

  @root %{
    "data_frame" => "people",
    "assign_to" => nil,
    "data_frame_alias" => Explorer.DataFrame,
    "missing_require" => nil
  }

  @base_operations %{
    fill_missing: [
      %{
        "column" => nil,
        "strategy" => "forward",
        "scalar" => nil,
        "type" => "string",
        "active" => true,
        "operation_type" => "fill_missing"
      }
    ],
    filters: [
      %{
        "column" => nil,
        "filter" => "equal",
        "type" => "string",
        "value" => nil,
        "active" => true,
        "operation_type" => "filters"
      }
    ],
    sorting: [
      %{"direction" => "asc", "sort_by" => nil, "active" => true, "operation_type" => "sorting"}
    ],
    pivot_wider: [
      %{
        "names_from" => nil,
        "values_from" => [],
        "active" => true,
        "operation_type" => "pivot_wider"
      }
    ],
    group_by: [
      %{"group_by" => [], "active" => true, "operation_type" => "group_by"}
    ]
  }

  test "returns no source when starting fresh with no data" do
    {_kino, source} = start_smart_cell!(DataTransformCell, %{})

    assert source == ""
  end

  test "finds Explorer DataFrames in binding and sends the data options to the client" do
    {kino, _source} = start_smart_cell!(DataTransformCell, %{})

    teams = teams_df()
    people = people_df()
    invalid_data = %{self() => [1, 2], :y => [1, 2]}

    env = Code.env_for_eval([])
    DataTransformCell.scan_binding(kino.pid, binding(), env)

    data_options = [
      %{columns: %{"id" => :integer, "name" => :string}, variable: "people"},
      %{
        columns: %{"hour" => :integer, "team" => :string, "weekday" => :string},
        variable: "teams"
      }
    ]

    assert_broadcast_event(kino, "set_available_data", %{"data_options" => ^data_options})
  end

  describe "code generation" do
    test "source for a data frame without operations" do
      attrs = build_attrs(%{})

      assert DataTransformCell.to_source(attrs) == """
             people\
             """
    end

    test "source for a data frame with sorting" do
      attrs =
        build_attrs(%{
          sorting: [
            %{
              "direction" => "asc",
              "sort_by" => "name",
              "active" => true,
              "operation_type" => "sorting"
            }
          ]
        })

      assert DataTransformCell.to_source(attrs) == """
             people |> Explorer.DataFrame.arrange(asc: name)\
             """
    end

    test "source for a data frame with multiple sorting" do
      attrs =
        build_attrs(%{
          sorting: [
            %{
              "direction" => "asc",
              "sort_by" => "name",
              "active" => true,
              "operation_type" => "sorting"
            },
            %{
              "direction" => "desc",
              "sort_by" => "id",
              "active" => true,
              "operation_type" => "sorting"
            }
          ]
        })

      assert DataTransformCell.to_source(attrs) == """
             people |> Explorer.DataFrame.arrange(asc: name, desc: id)\
             """
    end

    test "source for a data frame with filtering" do
      attrs =
        build_attrs(%{
          filters: [
            %{
              "column" => "name",
              "filter" => "equal",
              "type" => "string",
              "value" => "Ana",
              "active" => true,
              "operation_type" => "filters"
            }
          ]
        })

      assert DataTransformCell.to_source(attrs) == """
             people |> Explorer.DataFrame.filter(name == "Ana")\
             """
    end

    test "source for a data frame with multiple filtering" do
      attrs =
        build_attrs(%{
          filters: [
            %{
              "column" => "name",
              "filter" => "equal",
              "type" => "string",
              "value" => "Ana",
              "active" => true,
              "operation_type" => "filters"
            },
            %{
              "column" => "id",
              "filter" => "less",
              "type" => "integer",
              "value" => "2",
              "active" => true,
              "operation_type" => "filters"
            }
          ]
        })

      assert DataTransformCell.to_source(attrs) == """
             people |> Explorer.DataFrame.filter(name == "Ana" and id < 2)\
             """
    end

    test "do not generate code for invalid filters" do
      attrs =
        build_attrs(%{
          filters: [
            %{
              "column" => "name",
              "filter" => "equal",
              "type" => "string",
              "value" => "Ana",
              "active" => true,
              "operation_type" => "filters"
            },
            %{
              "column" => "id",
              "filter" => "less",
              "type" => "integer",
              "value" => "Ana",
              "active" => true,
              "operation_type" => "filters"
            }
          ]
        })

      assert DataTransformCell.to_source(attrs) == """
             people |> Explorer.DataFrame.filter(name == "Ana")\
             """
    end

    test "source for a data frame with fill_missing" do
      attrs =
        build_attrs(%{
          fill_missing: [
            %{
              "column" => "name",
              "strategy" => "forward",
              "scalar" => nil,
              "type" => "string",
              "active" => true,
              "operation_type" => "fill_missing"
            }
          ]
        })

      assert DataTransformCell.to_source(attrs) == """
             people |> Explorer.DataFrame.mutate(name: fill_missing(name, :forward))\
             """
    end

    test "source for a data frame with multiple fill_missing" do
      attrs =
        build_attrs(%{
          fill_missing: [
            %{
              "column" => "name",
              "strategy" => "forward",
              "scalar" => nil,
              "type" => "string",
              "active" => true,
              "operation_type" => "fill_missing"
            },
            %{
              "column" => "id",
              "strategy" => "scalar",
              "scalar" => "4",
              "type" => "integer",
              "active" => true,
              "operation_type" => "fill_missing"
            }
          ]
        })

      assert DataTransformCell.to_source(attrs) == """
             people
             |> Explorer.DataFrame.mutate(name: fill_missing(name, :forward), id: fill_missing(id, 4))\
             """
    end

    test "do not generate code for invalid fill_missing" do
      attrs =
        build_attrs(%{
          fill_missing: [
            %{
              "column" => "name",
              "strategy" => "scalar",
              "scalar" => "Ana",
              "type" => "string",
              "active" => true,
              "operation_type" => "fill_missing"
            },
            %{
              "column" => "id",
              "strategy" => "scalar",
              "scalar" => "invalid",
              "type" => "integer",
              "active" => true,
              "operation_type" => "fill_missing"
            }
          ]
        })

      assert DataTransformCell.to_source(attrs) == """
             people |> Explorer.DataFrame.mutate(name: fill_missing(name, "Ana"))\
             """
    end

    test "source for a data frame with columns with spaces" do
      root = %{"data_frame" => "df", "assign_to" => "new_df"}

      operations = %{
        sorting: [
          %{
            "direction" => "asc",
            "sort_by" => "full name",
            "active" => true,
            "operation_type" => "sorting"
          },
          %{
            "direction" => "desc",
            "sort_by" => "id",
            "active" => true,
            "operation_type" => "sorting"
          }
        ],
        filters: [
          %{
            "column" => "full name",
            "filter" => "equal",
            "type" => "string",
            "value" => "Ana",
            "active" => true,
            "operation_type" => "filters"
          },
          %{
            "column" => "id",
            "filter" => "less",
            "type" => "integer",
            "value" => "2",
            "active" => true,
            "operation_type" => "filters"
          }
        ]
      }

      attrs = build_attrs(root, operations)

      assert DataTransformCell.to_source(attrs) == """
             new_df =
               df
               |> Explorer.DataFrame.filter(col("full name") == "Ana" and id < 2)
               |> Explorer.DataFrame.arrange(asc: col("full name"), desc: id)\
             """
    end

    test "source for a data frame with group_by" do
      root = %{"data_frame" => "teams"}

      operations = %{
        group_by: [
          %{
            "group_by" => "weekdays",
            "active" => true,
            "operation_type" => "group_by"
          }
        ]
      }

      attrs = build_attrs(root, operations)

      assert DataTransformCell.to_source(attrs) == """
             teams |> Explorer.DataFrame.group_by("weekdays")\
             """
    end

    test "source for a data frame with group_by whit multiple columns" do
      root = %{"data_frame" => "teams"}

      operations = %{
        group_by: [
          %{
            "group_by" => ["hour", "day"],
            "active" => true,
            "operation_type" => "group_by"
          }
        ]
      }

      attrs = build_attrs(root, operations)

      assert DataTransformCell.to_source(attrs) == """
             teams |> Explorer.DataFrame.group_by(["hour", "day"])\
             """
    end

    test "source for a data frame with pivot wider" do
      root = %{"data_frame" => "teams"}

      operations = %{
        pivot_wider: [
          %{
            "names_from" => "weekdays",
            "values_from" => "hour",
            "active" => true,
            "operation_type" => "pivot_wider"
          }
        ]
      }

      attrs = build_attrs(root, operations)

      assert DataTransformCell.to_source(attrs) == """
             teams |> Explorer.DataFrame.pivot_wider("weekdays", "hour")\
             """
    end

    test "source for a data frame with pivot wider whit multiple values_from" do
      root = %{"data_frame" => "teams"}

      operations = %{
        pivot_wider: [
          %{
            "names_from" => "weekdays",
            "values_from" => ["hour", "day"],
            "active" => true,
            "operation_type" => "pivot_wider"
          }
        ]
      }

      attrs = build_attrs(root, operations)

      assert DataTransformCell.to_source(attrs) == """
             teams |> Explorer.DataFrame.pivot_wider("weekdays", ["hour", "day"])\
             """
    end

    test "source with alias" do
      root = %{"data_frame_alias" => DF}

      operations = %{
        filters: [
          %{
            "column" => "name",
            "filter" => "equal",
            "type" => "string",
            "value" => "Ana",
            "active" => true,
            "operation_type" => "filters"
          },
          %{
            "column" => "id",
            "filter" => "less",
            "type" => "integer",
            "value" => "2",
            "active" => true,
            "operation_type" => "filters"
          }
        ]
      }

      attrs = build_attrs(root, operations)

      assert DataTransformCell.to_source(attrs) == """
             people |> DF.filter(name == "Ana" and id < 2)\
             """
    end

    test "source with export to var and no operations" do
      attrs = build_attrs(%{"assign_to" => "exported_df"}, %{})

      assert DataTransformCell.to_source(attrs) == """
             exported_df = people\
             """
    end

    test "source with export to var" do
      root = %{"data_frame_alias" => DF, "assign_to" => "exported_df"}

      operations = %{
        filters: [
          %{
            "column" => "name",
            "filter" => "equal",
            "type" => "string",
            "value" => "Ana",
            "active" => true,
            "operation_type" => "filters"
          },
          %{
            "column" => "id",
            "filter" => "less",
            "type" => "integer",
            "value" => "2",
            "active" => true,
            "operation_type" => "filters"
          }
        ]
      }

      attrs = build_attrs(root, operations)

      assert DataTransformCell.to_source(attrs) == """
             exported_df = people |> DF.filter(name == "Ana" and id < 2)\
             """
    end

    test "source with inactive operations" do
      root = %{"data_frame_alias" => DF, "assign_to" => "exported_df"}

      operations = %{
        sorting: [
          %{
            "direction" => "asc",
            "sort_by" => "full name",
            "active" => true,
            "operation_type" => "sorting"
          },
          %{
            "direction" => "desc",
            "sort_by" => "id",
            "active" => false,
            "operation_type" => "sorting"
          }
        ],
        filters: [
          %{
            "column" => "name",
            "filter" => "equal",
            "type" => "string",
            "value" => "Ana",
            "active" => true,
            "operation_type" => "filters"
          },
          %{
            "column" => "id",
            "filter" => "less",
            "type" => "integer",
            "value" => "2",
            "active" => false,
            "operation_type" => "filters"
          }
        ],
        pivot_wider: [
          %{
            "names_from" => "name",
            "values_from" => "id",
            "active" => false,
            "operation_type" => "pivot_wider"
          }
        ]
      }

      attrs = build_attrs(root, operations)

      assert DataTransformCell.to_source(attrs) == """
             exported_df = people |> DF.filter(name == "Ana") |> DF.arrange(asc: col("full name"))\
             """
    end

    test "source with grouped and ungrouped operations" do
      root = %{
        "data_frame" => "people",
        "assign_to" => "exported_df",
        "data_frame_alias" => DF,
        "missing_require" => nil
      }

      operations = [
        %{
          "column" => "name",
          "filter" => "equal",
          "type" => "string",
          "value" => "Ana",
          "active" => true,
          "operation_type" => "filters"
        },
        %{
          "column" => "id",
          "filter" => "less",
          "type" => "integer",
          "value" => "2",
          "active" => true,
          "operation_type" => "filters"
        },
        %{
          "direction" => "asc",
          "sort_by" => "full name",
          "active" => true,
          "operation_type" => "sorting"
        },
        %{
          "column" => "surname",
          "filter" => "contains",
          "type" => "string",
          "value" => "Santiago",
          "active" => true,
          "operation_type" => "filters"
        }
      ]

      attrs = Map.put(root, "operations", operations)

      assert DataTransformCell.to_source(attrs) == """
             exported_df =
               people
               |> DF.filter(name == "Ana" and id < 2)
               |> DF.arrange(asc: col("full name"))
               |> DF.filter(contains(surname, "Santiago"))\
             """
    end

    test "source with an auto generated require" do
      root = %{
        "data_frame_alias" => DF,
        "assign_to" => "exported_df",
        "missing_require" => Explorer.DataFrame
      }

      operations = %{
        filters: [
          %{
            "column" => "name",
            "filter" => "equal",
            "type" => "string",
            "value" => "Ana",
            "active" => true,
            "operation_type" => "filters"
          },
          %{
            "column" => "id",
            "filter" => "less",
            "type" => "integer",
            "value" => "2",
            "active" => true,
            "operation_type" => "filters"
          }
        ]
      }

      attrs = build_attrs(root, operations)

      assert DataTransformCell.to_source(attrs) == """
             require Explorer.DataFrame
             exported_df = people |> DF.filter(name == "Ana" and id < 2)\
             """
    end
  end

  defp people_df() do
    Explorer.DataFrame.new(%{
      id: [3, 1, 2],
      name: ["Amy Santiago", "Jake Peralta", "Terry Jeffords"]
    })
  end

  defp teams_df() do
    Explorer.DataFrame.new(
      weekday: [
        "Monday",
        "Tuesday",
        "Wednesday",
        "Thursday",
        "Friday",
        "Monday",
        "Tuesday",
        "Wednesday",
        "Thursday",
        "Friday"
      ],
      team: ["A", "B", "C", "A", "B", "C", "A", "B", "C", "A"],
      hour: [10, 9, 10, 10, 11, 15, 14, 16, 14, 16]
    )
  end

  defp build_attrs(root_attrs \\ %{}, operations_attrs) do
    root_attrs = Map.merge(@root, root_attrs)
    operations = Map.merge(@base_operations, operations_attrs)

    operations =
      operations.fill_missing ++
        operations.filters ++ operations.sorting ++ operations.group_by ++ operations.pivot_wider

    Map.put(root_attrs, "operations", operations)
  end
end
