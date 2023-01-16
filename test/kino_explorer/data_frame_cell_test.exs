defmodule KinoExplorer.DataFrameCellTest do
  use ExUnit.Case, async: true

  import Kino.Test

  alias KinoExplorer.DataFrameCell

  setup :configure_livebook_bridge

  @root %{
    "data_frame" => "people",
    "export_to" => nil,
    "data_frame_alias" => Explorer.DataFrame
  }

  @operations %{
    "filters" => [%{"column" => nil, "filter" => "==", "type" => "string", "value" => nil}],
    "pivot_wider" => [%{"names_from" => nil, "values_from" => nil}],
    "sorting" => [%{"direction" => "asc", "sort_by" => nil}]
  }

  test "returns no source when starting fresh with no data" do
    {_kino, source} = start_smart_cell!(DataFrameCell, %{})

    assert source == ""
  end

  test "finds Explorer DataFrames in binding and sends the data options to the client" do
    {kino, _source} = start_smart_cell!(DataFrameCell, %{})

    teams = teams_df()
    people = people_df()
    invalid_data = %{self() => [1, 2], :y => [1, 2]}

    env = Code.env_for_eval([])
    DataFrameCell.scan_binding(kino.pid, binding(), env)

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

      assert DataFrameCell.to_source(attrs) == """
             people\
             """
    end

    test "source for a data frame with sorting" do
      attrs = build_attrs(%{"sorting" => [%{"direction" => "asc", "sort_by" => "name"}]})

      assert DataFrameCell.to_source(attrs) == """
             people |> Explorer.DataFrame.arrange(asc: name)\
             """
    end

    test "source for a data frame with multiple sorting" do
      attrs =
        build_attrs(%{
          "sorting" => [
            %{"direction" => "asc", "sort_by" => "name"},
            %{"direction" => "desc", "sort_by" => "id"}
          ]
        })

      assert DataFrameCell.to_source(attrs) == """
             people |> Explorer.DataFrame.arrange(asc: name, desc: id)\
             """
    end

    test "source for a data frame with filtering" do
      attrs =
        build_attrs(%{
          "filters" => [
            %{"column" => "name", "filter" => "==", "type" => "string", "value" => "Ana"}
          ]
        })

      assert DataFrameCell.to_source(attrs) == """
             people |> Explorer.DataFrame.filter(name == "Ana")\
             """
    end

    test "source for a data frame with multiple filtering" do
      attrs =
        build_attrs(%{
          "filters" => [
            %{"column" => "name", "filter" => "==", "type" => "string", "value" => "Ana"},
            %{"column" => "id", "filter" => "<", "type" => "integer", "value" => "2"}
          ]
        })

      assert DataFrameCell.to_source(attrs) == """
             people |> Explorer.DataFrame.filter(name == "Ana") |> Explorer.DataFrame.filter(id < 2)\
             """
    end

    test "sour for a data frame with columns with spaces" do
      root = %{"data_frame" => "df", "export_to" => "new_df"}

      operations = %{
        "sorting" => [
          %{"direction" => "asc", "sort_by" => "full name"},
          %{"direction" => "desc", "sort_by" => "id"}
        ],
        "filters" => [
          %{"column" => "full name", "filter" => "==", "type" => "string", "value" => "Ana"},
          %{"column" => "id", "filter" => "<", "type" => "integer", "value" => "2"}
        ]
      }

      attrs = build_attrs(root, operations)

      assert DataFrameCell.to_source(attrs) == """
             new_df =
               df
               |> Explorer.DataFrame.arrange(asc: col("full name"), desc: id)
               |> Explorer.DataFrame.filter(col("full name") == "Ana")
               |> Explorer.DataFrame.filter(id < 2)\
             """
    end

    test "source for a data frame with pivot wider" do
      root = %{"data_frame" => "teams"}
      operations = %{"pivot_wider" => [%{"names_from" => "weekdays", "values_from" => "hour"}]}
      attrs = build_attrs(root, operations)

      assert DataFrameCell.to_source(attrs) == """
             teams |> Explorer.DataFrame.pivot_wider("weekdays", "hour")\
             """
    end

    test "source with alias" do
      root = %{"data_frame_alias" => DF}

      operations = %{
        "filters" => [
          %{"column" => "name", "filter" => "==", "type" => "string", "value" => "Ana"},
          %{"column" => "id", "filter" => "<", "type" => "integer", "value" => "2"}
        ]
      }

      attrs = build_attrs(root, operations)

      assert DataFrameCell.to_source(attrs) == """
             people |> DF.filter(name == "Ana") |> DF.filter(id < 2)\
             """
    end

    test "source with export to var and no operations" do
      attrs = build_attrs(%{"export_to" => "exported_df"}, %{})

      assert DataFrameCell.to_source(attrs) == """
             exported_df = people\
             """
    end

    test "source with export to var" do
      root = %{"data_frame_alias" => DF, "export_to" => "exported_df"}

      operations = %{
        "filters" => [
          %{"column" => "name", "filter" => "==", "type" => "string", "value" => "Ana"},
          %{"column" => "id", "filter" => "<", "type" => "integer", "value" => "2"}
        ]
      }

      attrs = build_attrs(root, operations)

      assert DataFrameCell.to_source(attrs) == """
             exported_df = people |> DF.filter(name == "Ana") |> DF.filter(id < 2)\
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
    operations_attrs = Map.merge(@operations, operations_attrs)
    Map.put(root_attrs, "operations", operations_attrs)
  end
end
