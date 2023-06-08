defmodule KinoExplorer.DataTransformCellTest do
  use ExUnit.Case, async: true

  import Kino.Test

  alias KinoExplorer.DataTransformCell

  setup :configure_livebook_bridge

  @root %{
    "data_frame" => "people",
    "assign_to" => nil,
    "collect" => true,
    "data_frame_alias" => Explorer.DataFrame,
    "missing_require" => nil,
    "is_data_frame" => true
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
        "filter" => nil,
        "column" => nil,
        "value" => nil,
        "type" => "string",
        "active" => true,
        "operation_type" => "filters",
        "datalist" => []
      }
    ],
    sorting: [
      %{"sort_by" => nil, "direction" => "asc", "active" => true, "operation_type" => "sorting"}
    ],
    group_by: [
      %{"columns" => [], "active" => true, "operation_type" => "group_by"}
    ],
    summarise: [
      %{"columns" => [], "query" => nil, "active" => true, "operation_type" => "summarise"}
    ],
    discard: [
      %{"columns" => [], "active" => true, "operation_type" => "discard"}
    ],
    pivot_wider: [
      %{
        "names_from" => nil,
        "values_from" => [],
        "active" => true,
        "operation_type" => "pivot_wider"
      }
    ]
  }

  @base_attrs %{
    "assign_to" => nil,
    "data_frame" => "teams",
    "collect" => true,
    "data_frame_alias" => Explorer.DataFrame,
    "missing_require" => nil,
    "operations" => []
  }

  test "returns no source when starting fresh with no data" do
    {_kino, source} = start_smart_cell!(DataTransformCell, %{})

    assert source == ""
  end

  test "finds valid data in binding and sends the data options to the client" do
    {kino, _source} = start_smart_cell!(DataTransformCell, %{})

    teams = teams_df()
    people = people_df()

    simple_data = [
      %{id: 1, name: "Elixir", website: "https://elixir-lang.org"},
      %{id: 2, name: "Erlang", website: "https://www.erlang.org"}
    ]

    invalid_data = %{self() => [1, 2], :y => [1, 2]}

    env = Code.env_for_eval([])
    DataTransformCell.scan_binding(kino.pid, binding(), env)

    data_frame_variables = %{"people" => true, "simple_data" => false, "teams" => true}

    assert_broadcast_event(kino, "set_available_data", %{
      "data_frame_variables" => ^data_frame_variables,
      "fields" => %{
        operations: [
          %{
            "active" => true,
            "column" => nil,
            "data_options" => %{"id" => :integer, "name" => :string},
            "datalist" => [],
            "filter" => nil,
            "operation_type" => "filters",
            "type" => "string",
            "value" => nil
          }
        ],
        root_fields: %{"assign_to" => nil, "data_frame" => "people"}
      }
    })
  end

  test "initial data options for a non data_frame data" do
    {kino, _source} = start_smart_cell!(DataTransformCell, %{})

    simple_data = [
      %{id: 1, name: "Elixir", website: "https://elixir-lang.org"},
      %{id: 2, name: "Erlang", website: "https://www.erlang.org"}
    ]

    env = Code.env_for_eval([])
    DataTransformCell.scan_binding(kino.pid, binding(), env)

    data_frame_variables = %{"simple_data" => false}

    assert_broadcast_event(kino, "set_available_data", %{
      "data_frame_variables" => ^data_frame_variables,
      "fields" => %{
        operations: [
          %{
            "active" => true,
            "column" => nil,
            "data_options" => %{
              "id" => :integer,
              "name" => :string,
              "website" => :string
            },
            "datalist" => [],
            "filter" => nil,
            "operation_type" => "filters",
            "type" => "string",
            "value" => nil
          }
        ],
        root_fields: %{"assign_to" => nil, "data_frame" => "simple_data"}
      }
    })
  end

  describe "code generation" do
    test "source for a data frame without operations" do
      attrs = build_attrs(%{})

      assert DataTransformCell.to_source(attrs) == """
             people\
             """
    end

    test "source for a data without operations" do
      root = %{"data_frame" => "simple_data", "is_data_frame" => false}
      attrs = build_attrs(root, %{})

      assert DataTransformCell.to_source(attrs) == """
             simple_data |> Explorer.DataFrame.new(lazy: true) |> Explorer.DataFrame.collect()\
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
             people
             |> Explorer.DataFrame.to_lazy()
             |> Explorer.DataFrame.arrange(asc: name)
             |> Explorer.DataFrame.collect()\
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
             people
             |> Explorer.DataFrame.to_lazy()
             |> Explorer.DataFrame.arrange(asc: name, desc: id)
             |> Explorer.DataFrame.collect()\
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
             people
             |> Explorer.DataFrame.to_lazy()
             |> Explorer.DataFrame.filter(name == "Ana")
             |> Explorer.DataFrame.collect()\
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
             people
             |> Explorer.DataFrame.to_lazy()
             |> Explorer.DataFrame.filter(name == "Ana" and id < 2)
             |> Explorer.DataFrame.collect()\
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
             people
             |> Explorer.DataFrame.to_lazy()
             |> Explorer.DataFrame.filter(name == "Ana")
             |> Explorer.DataFrame.collect()\
             """
    end

    test "source for a data frame with a queried filter" do
      attrs =
        build_attrs(%{
          filters: [
            %{
              "column" => "id",
              "filter" => "greater",
              "type" => "integer",
              "value" => "mean",
              "active" => true,
              "operation_type" => "filters"
            }
          ]
        })

      assert DataTransformCell.to_source(attrs) == """
             people
             |> Explorer.DataFrame.to_lazy()
             |> Explorer.DataFrame.filter(id > mean(id))
             |> Explorer.DataFrame.collect()\
             """
    end

    test "source for a data frame with multiple queried filters" do
      attrs =
        build_attrs(%{
          filters: [
            %{
              "column" => "id",
              "filter" => "less",
              "type" => "integer",
              "value" => "median",
              "active" => true,
              "operation_type" => "filters"
            },
            %{
              "column" => "id",
              "filter" => "greater",
              "type" => "integer",
              "value" => "mean",
              "active" => true,
              "operation_type" => "filters"
            }
          ]
        })

      assert DataTransformCell.to_source(attrs) == """
             people
             |> Explorer.DataFrame.to_lazy()
             |> Explorer.DataFrame.filter(id < median(id) and id > mean(id))
             |> Explorer.DataFrame.collect()\
             """
    end

    test "do not generate code for invalid queried filters" do
      attrs =
        build_attrs(%{
          filters: [
            %{
              "column" => "id",
              "filter" => "less",
              "type" => "integer",
              "value" => "medians",
              "active" => true,
              "operation_type" => "filters"
            },
            %{
              "column" => "id",
              "filter" => "less",
              "type" => "integer",
              "value" => "means",
              "active" => true,
              "operation_type" => "filters"
            },
            %{
              "column" => "id",
              "filter" => "less",
              "type" => "integer",
              "value" => "median",
              "active" => true,
              "operation_type" => "filters"
            },
            %{
              "column" => "id",
              "filter" => "greater",
              "type" => "integer",
              "value" => "mean",
              "active" => true,
              "operation_type" => "filters"
            }
          ]
        })

      assert DataTransformCell.to_source(attrs) == """
             people
             |> Explorer.DataFrame.to_lazy()
             |> Explorer.DataFrame.filter(id < median(id) and id > mean(id))
             |> Explorer.DataFrame.collect()\
             """
    end

    test "source for a data frame with a filter by quantile" do
      attrs =
        build_attrs(%{
          filters: [
            %{
              "column" => "id",
              "filter" => "greater",
              "type" => "integer",
              "value" => "quantile(10)",
              "active" => true,
              "operation_type" => "filters"
            }
          ]
        })

      assert DataTransformCell.to_source(attrs) == """
             people
             |> Explorer.DataFrame.to_lazy()
             |> Explorer.DataFrame.filter(id > quantile(id, 0.1))
             |> Explorer.DataFrame.collect()\
             """
    end

    test "source for a data frame with multiple filters by quantile" do
      attrs =
        build_attrs(%{
          filters: [
            %{
              "column" => "id",
              "filter" => "less",
              "type" => "integer",
              "value" => "quantile(50)",
              "active" => true,
              "operation_type" => "filters"
            },
            %{
              "column" => "id",
              "filter" => "greater",
              "type" => "integer",
              "value" => "quantile(10)",
              "active" => true,
              "operation_type" => "filters"
            }
          ]
        })

      assert DataTransformCell.to_source(attrs) == """
             people
             |> Explorer.DataFrame.to_lazy()
             |> Explorer.DataFrame.filter(id < quantile(id, 0.5) and id > quantile(id, 0.1))
             |> Explorer.DataFrame.collect()\
             """
    end

    test "do not generate code for invalid quantiles" do
      attrs =
        build_attrs(%{
          filters: [
            %{
              "column" => "id",
              "filter" => "less",
              "type" => "integer",
              "value" => "quantile(150)",
              "active" => true,
              "operation_type" => "filters"
            },
            %{
              "column" => "id",
              "filter" => "less",
              "type" => "integer",
              "value" => "quantile(abc)",
              "active" => true,
              "operation_type" => "filters"
            },
            %{
              "column" => "id",
              "filter" => "less",
              "type" => "integer",
              "value" => "quantiles(10)",
              "active" => true,
              "operation_type" => "filters"
            },
            %{
              "column" => "id",
              "filter" => "less",
              "type" => "integer",
              "value" => "quantile(50)",
              "active" => true,
              "operation_type" => "filters"
            },
            %{
              "column" => "id",
              "filter" => "greater",
              "type" => "integer",
              "value" => "quantile(10)",
              "active" => true,
              "operation_type" => "filters"
            }
          ]
        })

      assert DataTransformCell.to_source(attrs) == """
             people
             |> Explorer.DataFrame.to_lazy()
             |> Explorer.DataFrame.filter(id < quantile(id, 0.5) and id > quantile(id, 0.1))
             |> Explorer.DataFrame.collect()\
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
             people
             |> Explorer.DataFrame.to_lazy()
             |> Explorer.DataFrame.mutate(name: fill_missing(name, :forward))
             |> Explorer.DataFrame.collect()\
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
             |> Explorer.DataFrame.to_lazy()
             |> Explorer.DataFrame.mutate(name: fill_missing(name, :forward), id: fill_missing(id, 4))
             |> Explorer.DataFrame.collect()\
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
             people
             |> Explorer.DataFrame.to_lazy()
             |> Explorer.DataFrame.mutate(name: fill_missing(name, "Ana"))
             |> Explorer.DataFrame.collect()\
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
               |> Explorer.DataFrame.to_lazy()
               |> Explorer.DataFrame.filter(col("full name") == "Ana" and id < 2)
               |> Explorer.DataFrame.arrange(asc: col("full name"), desc: id)
               |> Explorer.DataFrame.collect()\
             """
    end

    test "source for a data frame with group_by" do
      root = %{"data_frame" => "teams"}

      operations = %{
        group_by: [
          %{
            "columns" => "weekdays",
            "active" => true,
            "operation_type" => "group_by"
          }
        ]
      }

      attrs = build_attrs(root, operations)

      assert DataTransformCell.to_source(attrs) == """
             teams
             |> Explorer.DataFrame.to_lazy()
             |> Explorer.DataFrame.group_by("weekdays")
             |> Explorer.DataFrame.collect()\
             """
    end

    test "source for a data frame with group_by with multiple columns" do
      root = %{"data_frame" => "teams"}

      operations = %{
        group_by: [
          %{
            "columns" => ["hour", "day"],
            "active" => true,
            "operation_type" => "group_by"
          }
        ]
      }

      attrs = build_attrs(root, operations)

      assert DataTransformCell.to_source(attrs) == """
             teams
             |> Explorer.DataFrame.to_lazy()
             |> Explorer.DataFrame.group_by(["hour", "day"])
             |> Explorer.DataFrame.collect()\
             """
    end

    test "source for a data frame with summarise" do
      root = %{"data_frame" => "teams"}

      operations = %{
        group_by: [
          %{
            "columns" => "weekdays",
            "active" => true,
            "operation_type" => "group_by"
          }
        ],
        summarise: [
          %{
            "columns" => ["hour"],
            "query" => "max",
            "active" => true,
            "operation_type" => "summarise"
          }
        ]
      }

      attrs = build_attrs(root, operations)

      assert DataTransformCell.to_source(attrs) == """
             teams
             |> Explorer.DataFrame.to_lazy()
             |> Explorer.DataFrame.group_by("weekdays")
             |> Explorer.DataFrame.summarise(hour_max: max(hour))
             |> Explorer.DataFrame.collect()\
             """
    end

    test "source for a data frame with summarise with multiple columns" do
      root = %{"data_frame" => "teams"}

      operations = %{
        group_by: [
          %{
            "columns" => "weekdays",
            "active" => true,
            "operation_type" => "group_by"
          }
        ],
        summarise: [
          %{
            "columns" => ["hour", "day"],
            "query" => "max",
            "active" => true,
            "operation_type" => "summarise"
          }
        ]
      }

      attrs = build_attrs(root, operations)

      assert DataTransformCell.to_source(attrs) == """
             teams
             |> Explorer.DataFrame.to_lazy()
             |> Explorer.DataFrame.group_by("weekdays")
             |> Explorer.DataFrame.summarise(hour_max: max(hour), day_max: max(day))
             |> Explorer.DataFrame.collect()\
             """
    end

    test "source for a data frame with multiple summarise" do
      root = %{"data_frame" => "teams"}

      operations = %{
        group_by: [
          %{
            "columns" => "weekdays",
            "active" => true,
            "operation_type" => "group_by"
          }
        ],
        summarise: [
          %{
            "columns" => ["hour"],
            "query" => "max",
            "active" => true,
            "operation_type" => "summarise"
          },
          %{
            "columns" => ["hour", "day"],
            "query" => "min",
            "active" => true,
            "operation_type" => "summarise"
          }
        ]
      }

      attrs = build_attrs(root, operations)

      assert DataTransformCell.to_source(attrs) == """
             teams
             |> Explorer.DataFrame.to_lazy()
             |> Explorer.DataFrame.group_by("weekdays")
             |> Explorer.DataFrame.summarise(
               hour_max: max(hour),
               hour_min: min(hour),
               day_min: min(day)
             )
             |> Explorer.DataFrame.collect()\
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

    test "source for a data frame with discard" do
      root = %{"data_frame" => "teams"}

      operations = %{
        discard: [
          %{
            "columns" => "weekdays",
            "active" => true,
            "operation_type" => "discard"
          }
        ]
      }

      attrs = build_attrs(root, operations)

      assert DataTransformCell.to_source(attrs) == """
             teams
             |> Explorer.DataFrame.to_lazy()
             |> Explorer.DataFrame.discard("weekdays")
             |> Explorer.DataFrame.collect()\
             """
    end

    test "source for a data frame with discard with multiple columns" do
      root = %{"data_frame" => "teams"}

      operations = %{
        discard: [
          %{
            "columns" => ["hour", "day"],
            "active" => true,
            "operation_type" => "discard"
          }
        ]
      }

      attrs = build_attrs(root, operations)

      assert DataTransformCell.to_source(attrs) == """
             teams
             |> Explorer.DataFrame.to_lazy()
             |> Explorer.DataFrame.discard(["hour", "day"])
             |> Explorer.DataFrame.collect()\
             """
    end

    test "source for a data frame with alias" do
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
             people |> DF.to_lazy() |> DF.filter(name == "Ana" and id < 2) |> DF.collect()\
             """
    end

    test "source for a data with alias" do
      root = %{"data_frame_alias" => DF, "is_data_frame" => false}

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
             people |> DF.new(lazy: true) |> DF.filter(name == "Ana" and id < 2) |> DF.collect()\
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
             exported_df =
               people |> DF.to_lazy() |> DF.filter(name == "Ana" and id < 2) |> DF.collect()\
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
             exported_df =
               people
               |> DF.to_lazy()
               |> DF.filter(name == "Ana")
               |> DF.arrange(asc: col("full name"))
               |> DF.collect()\
             """
    end

    test "source with grouped and ungrouped operations" do
      root = %{
        "data_frame" => "people",
        "assign_to" => "exported_df",
        "data_frame_alias" => DF,
        "missing_require" => nil,
        "is_data_frame" => true,
        "collect" => true
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
               |> DF.to_lazy()
               |> DF.filter(name == "Ana" and id < 2)
               |> DF.arrange(asc: col("full name"))
               |> DF.filter(contains(surname, "Santiago"))
               |> DF.collect()\
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

             exported_df =
               people |> DF.to_lazy() |> DF.filter(name == "Ana" and id < 2) |> DF.collect()\
             """
    end

    test "source for a data frame without collect" do
      root = %{"collect" => false}

      operations = %{
        sorting: [
          %{
            "direction" => "asc",
            "sort_by" => "full name",
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
          }
        ]
      }

      attrs = build_attrs(root, operations)

      assert DataTransformCell.to_source(attrs) == """
             people
             |> Explorer.DataFrame.to_lazy()
             |> Explorer.DataFrame.filter(col("full name") == "Ana")
             |> Explorer.DataFrame.arrange(asc: col("full name"))\
             """
    end

    test "source for a data without collect" do
      root = %{"data_frame" => "simple_data", "is_data_frame" => false, "collect" => false}

      operations = %{
        sorting: [
          %{
            "direction" => "asc",
            "sort_by" => "full name",
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
          }
        ]
      }

      attrs = build_attrs(root, operations)

      assert DataTransformCell.to_source(attrs) == """
             simple_data
             |> Explorer.DataFrame.new(lazy: true)
             |> Explorer.DataFrame.filter(col("full name") == "Ana")
             |> Explorer.DataFrame.arrange(asc: col("full name"))\
             """
    end

    test "auto collect before a pivot_wider" do
      root = %{"data_frame" => "teams", "data_frame_alias" => DF, "collect" => false}

      operations = %{
        filters: [
          %{
            "column" => "weekdays",
            "filter" => "equal",
            "type" => "string",
            "value" => "Monday",
            "active" => true,
            "operation_type" => "filters"
          }
        ],
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
             teams
             |> DF.to_lazy()
             |> DF.filter(weekdays == "Monday")
             |> DF.collect()
             |> DF.pivot_wider("weekdays", "hour")\
             """
    end

    test "auto collect after a group followed by an operation other than summarise" do
      root = %{"data_frame" => "teams", "data_frame_alias" => DF, "collect" => false}

      operations = %{
        group_by: [
          %{
            "columns" => "weekdays",
            "active" => true,
            "operation_type" => "group_by"
          }
        ],
        sort: [
          %{
            "sort_by" => "weekdays",
            "direction" => "asc",
            "active" => true,
            "operation_type" => "sorting"
          }
        ]
      }

      attrs = build_attrs(root, operations)

      assert DataTransformCell.to_source(attrs) == """
             teams
             |> DF.to_lazy()
             |> DF.group_by("weekdays")
             |> DF.collect()
             |> DF.arrange(asc: weekdays)\
             """
    end

    test "does not auto collect after a group followed by a summarise" do
      root = %{"data_frame" => "teams", "data_frame_alias" => DF, "collect" => false}

      operations = %{
        group_by: [
          %{
            "columns" => "weekdays",
            "active" => true,
            "operation_type" => "group_by"
          }
        ],
        summarise: [
          %{
            "columns" => ["hour"],
            "query" => "max",
            "active" => true,
            "operation_type" => "summarise"
          }
        ]
      }

      attrs = build_attrs(root, operations)

      assert DataTransformCell.to_source(attrs) == """
             teams |> DF.to_lazy() |> DF.group_by("weekdays") |> DF.summarise(hour_max: max(hour))\
             """
    end

    test "does not auto collect after a group when it's the last operation" do
      root = %{"data_frame" => "teams", "data_frame_alias" => DF, "collect" => false}

      operations = %{
        group_by: [
          %{
            "columns" => "weekdays",
            "active" => true,
            "operation_type" => "group_by"
          }
        ]
      }

      attrs = build_attrs(root, operations)

      assert DataTransformCell.to_source(attrs) == """
             teams |> DF.to_lazy() |> DF.group_by("weekdays")\
             """
    end

    test "does not generate noop lazy and collect when a pivot_wider is the only operation" do
      root = %{"data_frame" => "teams", "data_frame_alias" => DF}

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
             teams |> DF.pivot_wider("weekdays", "hour")\
             """
    end
  end

  describe "operation events" do
    test "add operations" do
      for operation_type <- Map.keys(@base_operations) do
        {kino, _source} = start_smart_cell!(DataTransformCell, @base_attrs)
        connect(kino)

        push_event(kino, "add_operation", %{"operation_type" => to_string(operation_type)})
        operations = @base_operations[operation_type]

        assert_broadcast_event(kino, "set_operations", %{
          "operations" => ^operations
        })
      end
    end

    test "duplicate operations" do
      operations = @base_operations |> Map.keys() |> Enum.with_index()

      for {operation_type, index} <- operations, idx = index + 1 do
        attrs =
          @base_operations
          |> Map.delete(:pivot_wider)
          |> Map.values()
          |> List.flatten()
          |> then(&Map.put(@base_attrs, "operations", &1))

        {kino, _source} = start_smart_cell!(DataTransformCell, attrs)
        connect(kino)

        push_event(kino, "add_operation", %{
          "operation_type" => to_string(operation_type),
          "idx" => idx
        })

        operations =
          attrs["operations"] |> List.insert_at(idx, hd(@base_operations[operation_type]))

        assert_broadcast_event(kino, "set_operations", %{
          "operations" => ^operations
        })
      end
    end

    test "delete operations" do
      for operation_type <- Map.keys(@base_operations) do
        attrs = Map.put(@base_attrs, "operations", @base_operations[operation_type])
        {kino, _source} = start_smart_cell!(DataTransformCell, attrs)
        connect(kino)

        push_event(kino, "remove_operation", %{"idx" => 0})
        operations = []

        assert_broadcast_event(kino, "set_operations", %{
          "operations" => ^operations
        })
      end
    end

    test "move operations" do
      operations = @base_operations |> Map.keys() |> Enum.with_index()

      for {_operation_type, index} <- operations do
        attrs =
          @base_operations
          |> Map.drop([:pivot_wider])
          |> Map.values()
          |> List.flatten()
          |> then(&Map.put(@base_attrs, "operations", &1))

        remove = index
        add = if index == length(attrs["operations"]), do: index - 1, else: index + 1

        {kino, _source} = start_smart_cell!(DataTransformCell, attrs)
        connect(kino)

        push_event(kino, "move_operation", %{"removedIndex" => remove, "addedIndex" => add})

        {operation, operations} = List.pop_at(attrs["operations"], remove)
        operations = List.insert_at(operations, add, operation)

        assert_broadcast_event(kino, "set_operations", %{
          "operations" => ^operations
        })
      end
    end

    test "toggle operations" do
      operations =
        @base_operations |> Map.drop([:filters, :fill_missing, :summarise]) |> Map.keys()

      for operation_type <- operations do
        attrs = Map.put(@base_attrs, "operations", @base_operations[operation_type])
        {kino, _source} = start_smart_cell!(DataTransformCell, attrs)
        connect(kino)

        push_event(kino, "update_field", %{
          "operation_type" => to_string(operation_type),
          "field" => "active",
          "value" => false,
          "idx" => 0
        })

        assert_broadcast_event(kino, "set_operations", %{"operations" => [%{"active" => false}]})
      end
    end

    test "toggle operations with grouped fields" do
      operations =
        @base_operations |> Map.take([:filters, :fill_missing, :summarise]) |> Map.keys()

      for operation_type <- operations do
        attrs = Map.put(@base_attrs, "operations", @base_operations[operation_type])
        {kino, _source} = start_smart_cell!(DataTransformCell, attrs)
        connect(kino)

        push_event(kino, "update_field", %{
          "operation_type" => to_string(operation_type),
          "field" => "active",
          "value" => false,
          "idx" => 0
        })

        assert_broadcast_event(kino, "set_operations", %{"operations" => [%{"active" => false}]})
      end
    end
  end

  describe "root fields" do
    test "update date frame" do
      attrs =
        @base_operations
        |> Map.delete(:pivot_wider)
        |> Map.values()
        |> List.flatten()
        |> then(&Map.put(@base_attrs, "operations", &1))

      {kino, _source} = start_smart_cell!(DataTransformCell, attrs)
      connect(kino)

      push_event(kino, "update_field", %{"field" => "data_frame", "value" => "people"})

      assert_broadcast_event(kino, "update_data_frame", %{
        "fields" => %{root_fields: %{"assign_to" => nil, "data_frame" => "people"}}
      })
    end

    test "update assign to" do
      {kino, _source} = start_smart_cell!(DataTransformCell, @base_attrs)
      connect(kino)

      push_event(kino, "update_field", %{
        "operation_type" => nil,
        "field" => "assign_to",
        "value" => "df"
      })

      assert_broadcast_event(kino, "update_root", %{"fields" => %{"assign_to" => "df"}})
    end
  end

  test "autocomplete for filters" do
    attrs = Map.put(@base_attrs, "operations", @base_operations.filters)
    {kino, _source} = start_smart_cell!(DataTransformCell, attrs)
    connect(kino)
    teams = teams_df()
    env = Code.env_for_eval([])
    DataTransformCell.scan_binding(kino.pid, binding(), env)

    push_event(kino, "update_field", %{
      "operation_type" => "filters",
      "field" => "column",
      "value" => "team",
      "idx" => 0
    })

    assert_broadcast_event(kino, "set_operations", %{
      "operations" => [
        %{
          "active" => true,
          "column" => "team",
          "data_options" => %{"hour" => :integer, "team" => :string, "weekday" => :string},
          "datalist" => ["A", "B", "C"],
          "filter" => "equal",
          "message" => nil,
          "operation_type" => "filters",
          "type" => "string",
          "value" => nil
        }
      ]
    })
  end

  describe "synced data options" do
    test "update data_options after a summarise" do
      operations = [
        %{
          "active" => true,
          "column" => "team",
          "data_options" => %{
            "hour" => :integer,
            "team" => :string,
            "weekday" => :string
          },
          "datalist" => ["A", "B", "C"],
          "filter" => "equal",
          "message" => nil,
          "operation_type" => "filters",
          "type" => "string",
          "value" => "A"
        },
        %{
          "active" => true,
          "data_options" => %{
            "hour" => :integer,
            "team" => :string,
            "weekday" => :string
          },
          "columns" => ["weekday"],
          "operation_type" => "group_by"
        },
        %{
          "active" => true,
          "columns" => ["hour"],
          "data_options" => %{
            "hour" => :integer,
            "team" => :string,
            "weekday" => :string
          },
          "operation_type" => "summarise",
          "query" => "max"
        }
      ]

      attrs = Map.put(@base_attrs, "operations", operations)
      {kino, _source} = start_smart_cell!(DataTransformCell, attrs)
      connect(kino)
      teams = teams_df()
      env = Code.env_for_eval([])
      DataTransformCell.scan_binding(kino.pid, binding(), env)

      push_event(kino, "add_operation", %{"operation_type" => "filters"})

      synced_filter =
        @base_operations.filters
        |> hd()
        |> Map.put("data_options", %{"hour_max" => :integer, "weekday" => :string})

      updated_operations = operations ++ [synced_filter]

      assert_broadcast_event(kino, "set_operations", %{"operations" => ^updated_operations})
    end

    test "synced data_options respect grouped operations" do
      operations = [
        %{
          "active" => true,
          "column" => "team",
          "data_options" => %{
            "hour" => :integer,
            "team" => :string,
            "weekday" => :string
          },
          "datalist" => ["A", "B", "C"],
          "filter" => "equal",
          "message" => nil,
          "operation_type" => "filters",
          "type" => "string",
          "value" => "A"
        },
        %{
          "active" => true,
          "data_options" => %{
            "hour" => :integer,
            "team" => :string,
            "weekday" => :string
          },
          "columns" => ["weekday"],
          "operation_type" => "group_by"
        },
        %{
          "active" => true,
          "columns" => ["hour"],
          "data_options" => %{
            "hour" => :integer,
            "team" => :string,
            "weekday" => :string
          },
          "operation_type" => "summarise",
          "query" => "max"
        }
      ]

      attrs = Map.put(@base_attrs, "operations", operations)
      {kino, _source} = start_smart_cell!(DataTransformCell, attrs)
      connect(kino)
      teams = teams_df()
      env = Code.env_for_eval([])
      DataTransformCell.scan_binding(kino.pid, binding(), env)

      push_event(kino, "add_operation", %{"operation_type" => "summarise"})

      synced_summarise =
        @base_operations.summarise
        |> hd()
        |> Map.put("data_options", %{"hour" => :integer, "team" => :string, "weekday" => :string})

      updated_operations = operations ++ [synced_summarise]

      assert_broadcast_event(kino, "set_operations", %{"operations" => ^updated_operations})
    end
  end

  describe "synced datalists" do
    test "filtered datalist based on a previous filter" do
      operations = [
        %{
          "active" => true,
          "column" => "team",
          "data_options" => %{
            "hour" => :integer,
            "team" => :string,
            "weekday" => :string
          },
          "datalist" => ["A", "B", "C"],
          "filter" => "equal",
          "message" => nil,
          "operation_type" => "filters",
          "type" => "string",
          "value" => "A"
        },
        %{
          "filter" => nil,
          "column" => nil,
          "value" => nil,
          "type" => "string",
          "active" => true,
          "operation_type" => "filters",
          "datalist" => []
        }
      ]

      attrs = Map.put(@base_attrs, "operations", operations)
      {kino, _source} = start_smart_cell!(DataTransformCell, attrs)
      connect(kino)
      teams = teams_df()
      env = Code.env_for_eval([])
      DataTransformCell.scan_binding(kino.pid, binding(), env)

      push_event(kino, "update_field", %{
        "operation_type" => "filters",
        "field" => "column",
        "value" => "team",
        "idx" => 1
      })

      synced_filter = %{
        "active" => true,
        "column" => "team",
        "data_options" => %{
          "hour" => :integer,
          "team" => :string,
          "weekday" => :string
        },
        "datalist" => ["A"],
        "filter" => "equal",
        "message" => nil,
        "operation_type" => "filters",
        "type" => "string",
        "value" => nil
      }

      updated_operations = List.replace_at(operations, 1, synced_filter)

      assert_broadcast_event(kino, "set_operations", %{"operations" => ^updated_operations})
    end

    test "sync datalist after updates a previous filter" do
      operations = [
        %{
          "active" => true,
          "column" => "team",
          "data_options" => %{
            "hour" => :integer,
            "team" => :string,
            "weekday" => :string
          },
          "datalist" => ["A", "B", "C"],
          "filter" => "equal",
          "message" => nil,
          "operation_type" => "filters",
          "type" => "string",
          "value" => "A"
        },
        %{
          "active" => true,
          "column" => "team",
          "data_options" => %{
            "hour" => :integer,
            "team" => :string,
            "weekday" => :string
          },
          "datalist" => ["A"],
          "filter" => "equal",
          "message" => nil,
          "operation_type" => "filters",
          "type" => "string",
          "value" => nil
        }
      ]

      attrs = Map.put(@base_attrs, "operations", operations)
      {kino, _source} = start_smart_cell!(DataTransformCell, attrs)
      connect(kino)
      teams = teams_df()
      env = Code.env_for_eval([])
      DataTransformCell.scan_binding(kino.pid, binding(), env)

      push_event(kino, "update_field", %{
        "operation_type" => "filters",
        "field" => "value",
        "value" => "B",
        "idx" => 0
      })

      updated_filter = %{hd(operations) | "value" => "B"}
      synced_filter = %{List.last(operations) | "datalist" => ["B"]}

      updated_operations = [updated_filter, synced_filter]

      assert_broadcast_event(kino, "set_operations", %{"operations" => ^updated_operations})
    end
  end

  describe "sync or inject data_options after scan_binding" do
    test "injects the initial data_options to ensure backward compatibility" do
      operations = [
        %{
          "active" => true,
          "column" => "team",
          "datalist" => ["A", "B", "C"],
          "filter" => "equal",
          "message" => nil,
          "operation_type" => "filters",
          "type" => "string",
          "value" => "A"
        },
        %{
          "active" => true,
          "columns" => ["weekday"],
          "operation_type" => "group_by"
        },
        %{
          "active" => true,
          "columns" => ["hour"],
          "operation_type" => "summarise",
          "query" => "max"
        }
      ]

      attrs = Map.put(@base_attrs, "operations", operations)
      {kino, _source} = start_smart_cell!(DataTransformCell, attrs)
      connect(kino)
      teams = teams_df()
      env = Code.env_for_eval([])
      binding = binding() |> Keyword.delete(:operations)
      DataTransformCell.scan_binding(kino.pid, binding, env)

      updated_operations =
        Enum.map(
          operations,
          &Map.put(&1, "data_options", %{
            "hour" => :integer,
            "team" => :string,
            "weekday" => :string
          })
        )

      assert_broadcast_event(kino, "set_available_data", %{
        "fields" => %{
          operations: ^updated_operations,
          root_fields: %{"assign_to" => nil, "data_frame" => "teams"}
        },
        "data_frame_variables" => %{"teams" => true}
      })
    end

    test "injects the initial data_options respecting the previous operations" do
      operations = [
        %{
          "active" => true,
          "column" => "team",
          "datalist" => ["A", "B", "C"],
          "filter" => "equal",
          "message" => nil,
          "operation_type" => "filters",
          "type" => "string",
          "value" => "A"
        },
        %{
          "active" => true,
          "columns" => ["weekday"],
          "operation_type" => "group_by"
        },
        %{
          "active" => true,
          "columns" => ["hour"],
          "operation_type" => "summarise",
          "query" => "max"
        },
        %{"sort_by" => nil, "direction" => "asc", "active" => true, "operation_type" => "sorting"}
      ]

      attrs = Map.put(@base_attrs, "operations", operations)
      {kino, _source} = start_smart_cell!(DataTransformCell, attrs)
      connect(kino)
      teams = teams_df()
      env = Code.env_for_eval([])
      binding = binding() |> Keyword.delete(:operations)
      DataTransformCell.scan_binding(kino.pid, binding, env)

      {operations, [sort]} = Enum.split(operations, 3)

      updated_operations =
        Enum.map(
          operations,
          &Map.put(&1, "data_options", %{
            "hour" => :integer,
            "team" => :string,
            "weekday" => :string
          })
        )

      updated_sort =
        Map.put(sort, "data_options", %{"hour_max" => :integer, "weekday" => :string})

      updated_operations = updated_operations ++ [updated_sort]

      assert_broadcast_event(kino, "set_available_data", %{
        "fields" => %{
          operations: ^updated_operations,
          root_fields: %{"assign_to" => nil, "data_frame" => "teams"}
        },
        "data_frame_variables" => %{"teams" => true}
      })
    end
  end

  describe "invalid operations" do
    test "doesn't crash the smart cell when there're invalid operations" do
      operations = [
        %{
          "active" => true,
          "columns" => ["hour"],
          "data_options" => %{
            "hour" => :integer,
            "team" => :string,
            "weekday" => :string
          },
          "operation_type" => "summarise",
          "query" => "max"
        }
      ]

      attrs = Map.put(@base_attrs, "operations", operations)
      {kino, _source} = start_smart_cell!(DataTransformCell, attrs)
      connect(kino)
      teams = teams_df()
      env = Code.env_for_eval([])
      DataTransformCell.scan_binding(kino.pid, binding(), env)

      push_event(kino, "add_operation", %{"operation_type" => "filters"})
      updated_operations = operations ++ @base_operations.filters
      assert_broadcast_event(kino, "set_operations", %{"operations" => ^updated_operations})
    end

    test "allows user to recover from invalid operations" do
      operations = [
        %{
          "active" => true,
          "columns" => ["hour"],
          "data_options" => %{
            "hour" => :integer,
            "team" => :string,
            "weekday" => :string
          },
          "operation_type" => "summarise",
          "query" => "max"
        },
        %{
          "active" => true,
          "data_options" => %{
            "hour" => :integer,
            "team" => :string,
            "weekday" => :string
          },
          "columns" => ["weekday"],
          "operation_type" => "group_by"
        },
        %{
          "filter" => nil,
          "column" => nil,
          "value" => nil,
          "type" => "string",
          "active" => true,
          "operation_type" => "filters",
          "datalist" => []
        }
      ]

      attrs = Map.put(@base_attrs, "operations", operations)
      {kino, _source} = start_smart_cell!(DataTransformCell, attrs)
      connect(kino)
      teams = teams_df()
      env = Code.env_for_eval([])
      DataTransformCell.scan_binding(kino.pid, binding(), env)

      push_event(kino, "move_operation", %{"removedIndex" => 1, "addedIndex" => 0})
      {operations, [filter]} = Enum.split(operations, 2)
      {operation, operations} = List.pop_at(operations, 1)
      operations = List.insert_at(operations, 0, operation)

      synced_filter =
        Map.put(filter, "data_options", %{"hour_max" => :integer, "weekday" => :string})

      updated_operations = operations ++ [synced_filter]

      assert_broadcast_event(kino, "set_operations", %{"operations" => ^updated_operations})
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
    pivot_wider = Map.get(operations_attrs, :pivot_wider) || @base_operations.pivot_wider

    operations =
      Map.merge(@base_operations, operations_attrs)
      |> Map.delete(:pivot_wider)
      |> Map.values()
      |> List.flatten()
      |> then(&(&1 ++ pivot_wider))

    Map.put(root_attrs, "operations", operations)
  end
end
