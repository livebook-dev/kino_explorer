defmodule Kino.ExplorerTest do
  use ExUnit.Case, async: true

  import Kino.Test

  setup :configure_livebook_bridge

  defp people_df() do
    Explorer.DataFrame.new(%{
      id: [3, 1, 2],
      name: ["Amy Santiago", "Jake Peralta", "Terry Jeffords"],
      start: [
        ~N[2023-12-12 12:12:12.121212],
        ~N[2023-12-01 02:03:04.050607],
        ~N[2023-11-11 11:11:11.111111]
      ]
    })
  end

  test "column definitions include type" do
    widget = Kino.Explorer.new(people_df())
    data = connect(widget)

    assert %{
             features: [:export, :pagination, :sorting],
             content: %{
               columns: [
                 %{key: "0", label: "id", type: "number"},
                 %{key: "1", label: "name", type: "text"},
                 %{key: "2", label: "start", type: "date"}
               ]
             }
           } = data
  end

  test "rows order matches the given data frame by default" do
    widget = Kino.Explorer.new(people_df())
    data = connect(widget)

    assert %{
             content: %{
               data: [
                 ["3", "1", "2"],
                 ["Amy Santiago", "Jake Peralta", "Terry Jeffords"],
                 [
                   "2023-12-12 12:12:12.121212",
                   "2023-12-01 02:03:04.050607",
                   "2023-11-11 11:11:11.111111"
                 ]
               ],
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
        %{key: "1", label: "name", type: "text"},
        %{key: "2", label: "start", type: "date"}
      ],
      data: [
        ["2", "1", "3"],
        ["Terry Jeffords", "Jake Peralta", "Amy Santiago"],
        ["2023-11-11 11:11:11.111111", "2023-12-01 02:03:04.050607", "2023-12-12 12:12:12.121212"]
      ],
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
        id: [3, 1, 2, nil, nil, nil, nil],
        name: ["Amy Santiago", "Jake Peralta", "Terry Jeffords", "Jake Peralta", nil, nil, nil],
        woman: [true, false, false, false, nil, nil, nil]
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
                     values: ["1", "3", "2.0", "4"]
                   },
                   type: "number"
                 },
                 %{
                   key: "1",
                   label: "name",
                   summary: %{
                     keys: ["unique", "top", "top freq", "nulls"],
                     values: ["4", "Jake Peralta", "2", "3"]
                   },
                   type: "text"
                 },
                 %{
                   key: "2",
                   label: "woman",
                   summary: %{
                     keys: ["unique", "top", "top freq", "nulls"],
                     values: ["3", "false", "3", "3"]
                   },
                   type: "boolean"
                 }
               ]
             }
           } = data
  end

  # TODO: broken on Explorer 0.8.0
  test "support data summary for all nils" do
    df = Explorer.DataFrame.new(%{id: [nil, nil, nil, nil]})

    widget = Kino.Explorer.new(df)
    data = connect(widget)

    assert %{
             content: %{
               columns: [
                 %{
                   key: "0",
                   label: "id",
                   summary: %{keys: [], values: []},
                   type: "text"
                 }
               ]
             }
           } = data
  end

  test "support data summary for lists" do
    df = Explorer.DataFrame.new(%{list: Explorer.Series.from_list([[1, 2], [1]])})

    widget = Kino.Explorer.new(df)
    data = connect(widget)

    assert %{
             content: %{
               columns: [
                 %{
                   key: "0",
                   label: "list",
                   summary: %{
                     keys: ["unique", "top", "top freq", "nulls"],
                     values: ["2", "[1, 2]", "1", "0"]
                   },
                   type: "list"
                 }
               ]
             }
           } = data
  end

  test "support data summary for lists with nil" do
    df = Explorer.DataFrame.new(%{list: Explorer.Series.from_list([[1, 2], [1], nil])})

    widget = Kino.Explorer.new(df)
    data = connect(widget)

    assert %{
             content: %{
               columns: [
                 %{
                   key: "0",
                   label: "list",
                   summary: %{
                     keys: ["unique", "top", "top freq", "nulls"],
                     values: ["3", "[1, 2]", "1", "1"]
                   },
                   type: "list"
                 }
               ]
             }
           } = data
  end

  test "does not break on lists with internal nulls" do
    df = Explorer.DataFrame.new(%{list: Explorer.Series.from_list([[1, 2], [1, nil]])})

    widget = Kino.Explorer.new(df)
    data = connect(widget)

    assert %{
             content: %{
               columns: [
                 %{key: "0", label: "list", summary: %{keys: [], values: []}, type: "list"}
               ]
             }
           } = data
  end

  test "shows if a column is in a group when there are groups" do
    df =
      Explorer.DataFrame.new(%{
        id: [3, 1, 2, nil],
        name: ["Amy Santiago", "Jake Peralta", "Terry Jeffords", "Jake Peralta"]
      })
      |> Explorer.DataFrame.group_by(:name)

    widget = Kino.Explorer.new(df)
    data = connect(widget)

    assert %{
             content: %{
               columns: [
                 %{
                   key: "0",
                   label: "id",
                   summary: %{
                     keys: ["min", "max", "mean", "nulls", "grouped"],
                     values: ["1", "3", "2.0", "1", "false"]
                   },
                   type: "number"
                 },
                 %{
                   key: "1",
                   label: "name",
                   summary: %{
                     keys: ["unique", "top", "top freq", "nulls", "grouped"],
                     values: ["3", "Jake Peralta", "2", "0", "true"]
                   },
                   type: "text"
                 }
               ]
             }
           } = data
  end

  test "supports infinity" do
    df = Explorer.DataFrame.new(a: [:infinity])
    widget = Kino.Explorer.new(df)
    data = connect(widget)

    assert %{
             content: %{
               columns: [
                 %{
                   key: "0",
                   label: "a",
                   summary: %{
                     keys: ["min", "max", "mean", "nulls"],
                     values: ["infinity", "infinity", "infinity", "0"]
                   },
                   type: "number"
                 }
               ]
             }
           } = data
  end

  test "supports types" do
    df =
      Explorer.DataFrame.new(
        [
          a: ["a", "b"],
          b: [1, 2],
          c: ["https://elixir-lang.org", "https://www.erlang.org"],
          d: [<<110, 120>>, <<200, 210>>],
          e: [[1, 2], [3, 4]]
        ],
        dtypes: [d: :binary]
      )

    widget = Kino.Explorer.new(df)
    data = connect(widget)
    types = ["text", "number", "uri", "binary", "list"]

    assert get_in(data.content.columns, [Access.all(), :type]) == types
  end

  test "correctly handles empty data frames with string columns" do
    df =
      Explorer.Datasets.iris()
      |> Explorer.DataFrame.filter_with(&Explorer.Series.equal(&1["sepal_length"], 3))

    widget = Kino.Explorer.new(df)
    data = connect(widget)

    assert %{
             features: [:export, :pagination, :sorting],
             content: %{
               columns: [
                 %{key: "0", label: "sepal_length", summary: nil, type: "number"},
                 %{key: "1", label: "sepal_width", summary: nil, type: "number"},
                 %{key: "2", label: "petal_length", summary: nil, type: "number"},
                 %{key: "3", label: "petal_width", summary: nil, type: "number"},
                 %{key: "4", label: "species", summary: nil, type: "text"}
               ],
               data: [[], [], [], [], []]
             }
           } = data
  end

  test "correctly handles data frames with binary non-utf8 column values" do
    df =
      Explorer.DataFrame.new([x: [1, 2], y: [<<110, 120>>, <<200, 210>>]], dtypes: [y: :binary])

    widget = Kino.Explorer.new(df)
    data = connect(widget)

    assert %{
             features: [:export, :pagination, :sorting],
             content: %{
               data: [["1", "2"], ["nx", "<<200, 210>>"]]
             }
           } = data
  end

  test "supports lazy data frames" do
    df = Explorer.Datasets.iris() |> Explorer.DataFrame.lazy()
    widget = Kino.Explorer.new(df)
    data = connect(widget)

    assert %{
             features: [:export, :pagination, :sorting],
             content: %{
               total_rows: nil,
               columns: [
                 %{
                   key: "0",
                   label: "sepal_length",
                   summary: nil,
                   type: "number"
                 },
                 %{
                   key: "1",
                   label: "sepal_width",
                   summary: nil,
                   type: "number"
                 },
                 %{
                   key: "2",
                   label: "petal_length",
                   summary: nil,
                   type: "number"
                 },
                 %{
                   key: "3",
                   label: "petal_width",
                   summary: nil,
                   type: "number"
                 },
                 %{
                   key: "4",
                   label: "species",
                   summary: nil,
                   type: "text"
                 }
               ]
             },
             name: "Lazy - DataFrame"
           } = data
  end

  test "supports export" do
    df = Explorer.DataFrame.new(%{n: Enum.to_list(1..25)})

    widget = Kino.Explorer.new(df)
    data = connect(widget)

    assert %{
             export: %{formats: ["CSV", "NDJSON", "Parquet"]},
             features: [:export, :pagination, :sorting],
             content: %{
               page: 1,
               max_page: 3,
               data: [["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]]
             }
           } = data

    for format <- ["CSV", "NDJSON", "Parquet"] do
      extension = ".#{String.downcase(format)}"
      push_event(widget, "download", %{"format" => format})
      assert_receive({:event, "download_content", {:binary, exported, data}, _})
      assert %{format: ^extension} = exported
      assert is_binary(data)
    end
  end

  test "supports export for lazy data frames" do
    df = Explorer.DataFrame.new(%{n: Enum.to_list(1..25)}, lazy: true)

    widget = Kino.Explorer.new(df)
    data = connect(widget)

    assert %{
             export: %{formats: ["CSV", "NDJSON", "Parquet"]},
             features: [:export, :pagination, :sorting],
             content: %{
               page: 1,
               max_page: nil,
               data: [["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]]
             }
           } = data

    for format <- ["CSV", "NDJSON", "Parquet"] do
      extension = ".#{String.downcase(format)}"
      push_event(widget, "download", %{"format" => format})
      assert_receive({:event, "download_content", {:binary, exported, data}, _})
      assert %{format: ^extension} = exported
      assert is_binary(data)
    end
  end

  test "export to" do
    df = Explorer.DataFrame.new(%{n: Enum.to_list(1..25)})

    for format <- ["CSV", "NDJSON", "Parquet"] do
      exported = Kino.Explorer.export_data(%{df: df}, format)
      extension = ".#{String.downcase(format)}"
      assert %{extension: ^extension} = exported
    end
  end

  test "export to for lazy data frames" do
    df = Explorer.DataFrame.new(%{n: Enum.to_list(1..25)}, lazy: true)

    for format <- ["CSV", "NDJSON", "Parquet"] do
      exported = Kino.Explorer.export_data(%{df: df}, format)
      extension = ".#{String.downcase(format)}"
      assert %{extension: ^extension} = exported
    end
  end

  test "export to for data frames with list-type columns" do
    df = Explorer.DataFrame.new(%{list: Explorer.Series.from_list([[1, 2], [1]])})

    widget = Kino.Explorer.new(df)
    data = connect(widget)

    assert %{export: %{formats: ["NDJSON", "Parquet"]}} = data

    for format <- ["NDJSON", "Parquet"] do
      exported = Kino.Explorer.export_data(%{df: df}, format)
      extension = ".#{String.downcase(format)}"
      assert %{extension: ^extension} = exported
    end
  end
end
