defmodule Kino.ExplorerTest do
  use ExUnit.Case, async: true

  import Kino.Test

  setup :configure_livebook_bridge

  defp people_df() do
    Explorer.DataFrame.new(%{
      id: [3, 1, 2],
      name: ["Amy Santiago", "Jake Peralta", "Terry Jeffords"]
    })
  end

  test "column definitions include type" do
    widget = Kino.Explorer.new(people_df())
    data = connect(widget)

    assert %{
             features: [:pagination, :sorting, :filtering],
             content: %{
               columns: [
                 %{key: "0", label: "id", type: "number"},
                 %{key: "1", label: "name", type: "text"}
               ]
             }
           } = data
  end

  test "rows order matches the given data frame by default" do
    widget = Kino.Explorer.new(people_df())
    data = connect(widget)

    assert %{
             content: %{
               data: [["3", "1", "2"], ["Amy Santiago", "Jake Peralta", "Terry Jeffords"]],
               total_rows: 3
             }
           } = data
  end

  test "supports sorting by other columns" do
    widget = Kino.Explorer.new(people_df())

    connect(widget)

    push_event(widget, "order_by", %{"key" => "1", "direction" => "desc"})

    assert_broadcast_event(widget, "update_content", %{
      columns: [
        %{key: "0", label: "id", type: "number"},
        %{key: "1", label: "name", type: "text"}
      ],
      data: [["2", "1", "3"], ["Terry Jeffords", "Jake Peralta", "Amy Santiago"]],
      order: %{direction: :desc, key: "1"}
    })
  end

  test "supports pagination" do
    df = Explorer.DataFrame.new(%{n: Enum.to_list(1..25)})

    widget = Kino.Explorer.new(df)
    data = connect(widget)

    assert %{
             content: %{
               page: 1,
               max_page: 3,
               data: [["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]]
             }
           } = data

    push_event(widget, "show_page", %{"page" => 2})

    assert_broadcast_event(widget, "update_content", %{
      page: 2,
      max_page: 3,
      data: [["11", "12", "13", "14", "15", "16", "17", "18", "19", "20"]]
    })
  end

  test "supports pagination limit" do
    df = Explorer.DataFrame.new(%{n: Enum.to_list(1..25)})

    widget = Kino.Explorer.new(df)
    data = connect(widget)

    assert %{
             content: %{
               page: 1,
               max_page: 3,
               data: [["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]]
             }
           } = data

    push_event(widget, "limit", %{"limit" => 15})

    assert_broadcast_event(widget, "update_content", %{
      page: 1,
      max_page: 2,
      data: [["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15"]]
    })
  end

  test "supports data summary" do
    df =
      Explorer.DataFrame.new(%{
        id: [3, 1, 2, nil],
        name: ["Amy Santiago", "Jake Peralta", "Terry Jeffords", "Jake Peralta"]
      })

    widget = Kino.Explorer.new(df)
    data = connect(widget)

    assert %{
             content: %{
               columns: [
                 %{
                   key: "0",
                   label: "id",
                   summary: %{
                     keys: ["min", "max", "mean", "nulls"],
                     values: ["1", "3", "2.0", "1"]
                   },
                   type: "number"
                 },
                 %{
                   key: "1",
                   label: "name",
                   summary: %{
                     keys: ["unique", "top", "top_freq", "nulls"],
                     values: ["3", "Jake Peralta", "2", "0"]
                   },
                   type: "text"
                 }
               ]
             }
           } = data
  end

  test "supports types" do
    df =
      Explorer.DataFrame.new(
        a: ["a", "b"],
        b: [1, 2],
        c: ["https://elixir-lang.org", "https://www.erlang.org"]
      )

    widget = Kino.Explorer.new(df)
    data = connect(widget)

    assert get_in(data.content.columns, [Access.all(), :type]) == ["text", "number", "uri"]
  end

  test "supports filtering" do
    widget = Kino.Explorer.new(people_df())

    connect(widget)

    push_event(widget, "filter_by", %{
      "column" => "name",
      "key" => "1",
      "filter" => "equal",
      "value" => "Amy Santiago"
    })

    assert_broadcast_event(widget, "update_content", %{
      columns: [
        %{key: "0", label: "id", type: "number"},
        %{key: "1", label: "name", type: "text"}
      ],
      data: [["3"], ["Amy Santiago"]]
    })
  end

  test "supports cumulative filtering" do
    df =
      Explorer.DataFrame.new(%{
        id: [3, 1, 2, 0],
        name: ["Amy Santiago", "Jake Peralta", "Terry Jeffords", "Amy Jake"]
      })

    widget = Kino.Explorer.new(df)

    connect(widget)

    push_event(widget, "filter_by", %{
      "column" => "id",
      "key" => "0",
      "filter" => "less",
      "value" => 3
    })

    assert_broadcast_event(widget, "update_content", %{
      columns: [
        %{key: "0", label: "id", type: "number"},
        %{key: "1", label: "name", type: "text"}
      ],
      data: [["1", "2", "0"], ["Jake Peralta", "Terry Jeffords", "Amy Jake"]]
    })

    push_event(widget, "filter_by", %{
      "column" => "name",
      "key" => "1",
      "filter" => "contains",
      "value" => "Jake"
    })

    assert_broadcast_event(widget, "update_content", %{
      columns: [
        %{key: "0", label: "id", type: "number"},
        %{key: "1", label: "name", type: "text"}
      ],
      data: [["1", "0"], ["Jake Peralta", "Amy Jake"]]
    })
  end

  test "correctly handles empty data frames" do
    df = Explorer.DataFrame.new(%{id: []})
    widget = Kino.Explorer.new(df)
    data = connect(widget)

    assert %{
             features: [:pagination, :sorting, :filtering],
             content: %{
               columns: [%{key: "0", label: "id", type: "number", summary: nil}],
               data: [[]]
             }
           } = data
  end
end
