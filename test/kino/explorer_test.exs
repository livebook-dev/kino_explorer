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
    kino = Kino.Explorer.new(people_df())
    data = connect(kino)

    assert %{
             features: [:export, :pagination, :sorting, :relocate],
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
    kino = Kino.Explorer.new(people_df())
    data = connect(kino)

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
    kino = Kino.Explorer.new(people_df())

    connect(kino)

    push_event(kino, "order_by", %{"key" => "1", "direction" => "desc"})

    assert_broadcast_event(kino, "update_content", %{
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

    kino = Kino.Explorer.new(df)
    data = connect(kino)

    assert %{
             content: %{
               page: 1,
               max_page: 3,
               data: [["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]]
             }
           } = data

    push_event(kino, "show_page", %{"page" => 2})

    assert_broadcast_event(kino, "update_content", %{
      page: 2,
      max_page: 3,
      data: [["11", "12", "13", "14", "15", "16", "17", "18", "19", "20"]]
    })
  end

  test "supports pagination limit" do
    df = Explorer.DataFrame.new(%{n: Enum.to_list(1..25)})

    kino = Kino.Explorer.new(df)
    data = connect(kino)

    assert %{
             content: %{
               page: 1,
               max_page: 3,
               data: [["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]]
             }
           } = data

    push_event(kino, "limit", %{"limit" => 15})

    assert_broadcast_event(kino, "update_content", %{
      page: 1,
      max_page: 2,
      data: [["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15"]]
    })
  end

  test "supports relocate" do
    kino = Kino.Explorer.new(people_df())

    connect(kino)

    push_event(kino, "relocate", %{"from_index" => 1, "to_index" => 0})

    assert_broadcast_event(kino, "update_content", %{
      columns: [
        %{key: "1", label: "name", type: "text"},
        %{key: "0", label: "id", type: "number"},
        %{key: "2", label: "start", type: "date"}
      ],
      data: [
        ["Amy Santiago", "Jake Peralta", "Terry Jeffords"],
        ["3", "1", "2"],
        ["2023-12-12 12:12:12.121212", "2023-12-01 02:03:04.050607", "2023-11-11 11:11:11.111111"]
      ],
      relocates: [%{from_index: 1, to_index: 0}]
    })
  end

  test "supports data summary" do
    df =
      Explorer.DataFrame.new(%{
        id: [3, 1, 2, nil, nil, nil, nil],
        name: ["Amy Santiago", "Jake Peralta", "Terry Jeffords", "Jake Peralta", nil, nil, nil],
        woman: [true, false, false, false, nil, nil, nil]
      })

    kino = Kino.Explorer.new(df)
    data = connect(kino)

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
                     values: ["3", "Jake Peralta", "2", "3"]
                   },
                   type: "text"
                 },
                 %{
                   key: "2",
                   label: "woman",
                   summary: %{
                     keys: ["unique", "top", "top freq", "nulls"],
                     values: ["2", "false", "3", "3"]
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

    kino = Kino.Explorer.new(df)
    data = connect(kino)

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

    kino = Kino.Explorer.new(df)
    data = connect(kino)

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

    kino = Kino.Explorer.new(df)
    data = connect(kino)

    assert %{
             content: %{
               columns: [
                 %{
                   key: "0",
                   label: "list",
                   summary: %{
                     keys: ["unique", "top", "top freq", "nulls"],
                     values: ["2", "[1, 2]", "1", "1"]
                   },
                   type: "list"
                 }
               ]
             }
           } = data
  end

  test "does not break on lists with internal nulls" do
    df = Explorer.DataFrame.new(%{list: Explorer.Series.from_list([[1, 2], [1, nil]])})

    kino = Kino.Explorer.new(df)
    data = connect(kino)

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

    kino = Kino.Explorer.new(df)
    data = connect(kino)

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
    kino = Kino.Explorer.new(df)
    data = connect(kino)

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

    kino = Kino.Explorer.new(df)
    data = connect(kino)
    types = ["text", "number", "uri", "binary", "list"]

    assert get_in(data.content.columns, [Access.all(), :type]) == types
  end

  test "correctly handles empty data frames with string columns" do
    df =
      Explorer.Datasets.iris()
      |> Explorer.DataFrame.filter_with(&Explorer.Series.equal(&1["sepal_length"], 3))

    kino = Kino.Explorer.new(df)
    data = connect(kino)

    assert %{
             features: [:export, :pagination, :sorting, :relocate],
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

    kino = Kino.Explorer.new(df)
    data = connect(kino)

    assert %{
             features: [:export, :pagination, :sorting, :relocate],
             content: %{
               data: [["1", "2"], ["nx", "<<200, 210>>"]]
             }
           } = data
  end

  test "supports lazy data frames" do
    df = Explorer.Datasets.iris() |> Explorer.DataFrame.lazy()
    kino = Kino.Explorer.new(df)
    data = connect(kino)

    assert %{
             features: [:export, :pagination, :sorting, :relocate],
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

    kino = Kino.Explorer.new(df)
    data = connect(kino)

    assert %{
             export: %{formats: ["CSV", "NDJSON", "Parquet"]},
             features: [:export, :pagination, :sorting, :relocate],
             content: %{
               page: 1,
               max_page: 3,
               data: [["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]]
             }
           } = data

    for format <- ["CSV", "NDJSON", "Parquet"] do
      extension = ".#{String.downcase(format)}"
      push_event(kino, "download", %{"format" => format})
      assert_receive({:event, "download_content", {:binary, exported, data}, _})
      assert %{format: ^extension} = exported
      assert is_binary(data)
    end
  end

  test "supports export for lazy data frames" do
    df = Explorer.DataFrame.new(%{n: Enum.to_list(1..25)}, lazy: true)

    kino = Kino.Explorer.new(df)
    data = connect(kino)

    assert %{
             export: %{formats: ["CSV", "NDJSON", "Parquet"]},
             features: [:export, :pagination, :sorting, :relocate],
             content: %{
               page: 1,
               max_page: nil,
               data: [["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]]
             }
           } = data

    for format <- ["CSV", "NDJSON", "Parquet"] do
      extension = ".#{String.downcase(format)}"
      push_event(kino, "download", %{"format" => format})
      assert_receive({:event, "download_content", {:binary, exported, data}, _})
      assert %{format: ^extension} = exported
      assert is_binary(data)
    end
  end

  test "export to" do
    df = Explorer.DataFrame.new(%{n: Enum.to_list(1..25)})
    rows_spec = %{order: nil, relocates: []}

    for format <- ["CSV", "NDJSON", "Parquet"] do
      exported = Kino.Explorer.export_data(rows_spec, %{df: df}, format)
      extension = ".#{String.downcase(format)}"
      assert {:ok, %{extension: ^extension}} = exported
    end
  end

  test "export to for lazy data frames" do
    df = Explorer.DataFrame.new(%{n: Enum.to_list(1..25)}, lazy: true)
    rows_spec = %{order: nil, relocates: []}

    for format <- ["CSV", "NDJSON", "Parquet"] do
      exported = Kino.Explorer.export_data(rows_spec, %{df: df}, format)
      extension = ".#{String.downcase(format)}"
      assert {:ok, %{extension: ^extension}} = exported
    end
  end

  test "export to for data frames with list-type columns" do
    df = Explorer.DataFrame.new(%{list: Explorer.Series.from_list([[1, 2], [1]])})
    rows_spec = %{order: nil, relocates: []}

    kino = Kino.Explorer.new(df)
    data = connect(kino)

    assert %{export: %{formats: ["NDJSON", "Parquet"]}} = data

    for format <- ["NDJSON", "Parquet"] do
      exported = Kino.Explorer.export_data(rows_spec, %{df: df}, format)
      extension = ".#{String.downcase(format)}"
      assert {:ok, %{extension: ^extension}} = exported
    end
  end

  test "supports update" do
    df = Explorer.DataFrame.new(%{n: Enum.to_list(1..25)})

    kino = Kino.Explorer.new(df)
    data = connect(kino)

    assert %{
             content: %{
               page: 1,
               max_page: 3,
               data: [["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]]
             }
           } = data

    new_df = Explorer.DataFrame.new(%{n: Enum.to_list(25..50)})
    Kino.Explorer.update(kino, new_df)

    assert_broadcast_event(kino, "update_content", %{
      page: 1,
      max_page: 3,
      data: [["25", "26", "27", "28", "29", "30", "31", "32", "33", "34"]]
    })
  end
end
