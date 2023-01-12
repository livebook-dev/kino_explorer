defmodule KinoExplorer.DataFrameCellTest do
  use ExUnit.Case, async: true

  import Kino.Test

  alias KinoExplorer.DataFrameCell

  setup :configure_livebook_bridge

  @root %{
    "data_frame" => "people",
    "explorer_alias" => Explorer
  }

  @operations %{
    "filters" => [%{"column" => nil, "filter" => "equal", "type" => "string", "value" => nil}],
    "pivot_wider" => [%{"names_from" => nil, "values_from" => nil}],
    "sorting" => [%{"order" => "asc", "order_by" => nil}]
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
      attrs = build_attrs(%{"sorting" => [%{"order" => "asc", "order_by" => "name"}]})

      assert DataFrameCell.to_source(attrs) == """
             people |> Explorer.DataFrame.arrange_with(&[asc: &1["name"]])\
             """
    end

    test "source for a data frame with multiple sorting" do
      attrs =
        build_attrs(%{
          "sorting" => [
            %{"order" => "asc", "order_by" => "name"},
            %{"order" => "desc", "order_by" => "id"}
          ]
        })

      assert DataFrameCell.to_source(attrs) == """
             people |> Explorer.DataFrame.arrange_with(&[asc: &1["name"], desc: &1["id"]])\
             """
    end

    test "source for a data frame with filtering" do
      attrs =
        build_attrs(%{
          "filters" => [
            %{"column" => "name", "filter" => "equal", "type" => "string", "value" => "Ana"}
          ]
        })

      assert DataFrameCell.to_source(attrs) == """
             people |> Explorer.DataFrame.filter_with(&Explorer.Series.equal(&1["name"], "Ana"))\
             """
    end

    test "source for a data frame with multiple filtering" do
      attrs =
        build_attrs(%{
          "filters" => [
            %{"column" => "name", "filter" => "equal", "type" => "string", "value" => "Ana"},
            %{"column" => "id", "filter" => "less", "type" => "integer", "value" => "2"}
          ]
        })

      assert DataFrameCell.to_source(attrs) == """
             people
             |> Explorer.DataFrame.filter_with(&Explorer.Series.equal(&1["name"], "Ana"))
             |> Explorer.DataFrame.filter_with(&Explorer.Series.less(&1["id"], 2))\
             """
    end

    test "source for a data frame with pivot wider" do
      root = %{"data_frame" => "teams", "pivot_type" => "pivot_wider"}
      operations = %{"pivot_wider" => [%{"names_from" => "weekdays", "values_from" => "hour"}]}
      attrs = build_attrs(root, operations)

      assert DataFrameCell.to_source(attrs) == """
             teams |> Explorer.DataFrame.pivot_wider("weekdays", "hour")\
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
