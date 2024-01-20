defmodule Kino.Explorer do
  @moduledoc """
  A kino for interactively viewing `Explorer.DataFrame`.

  ## Examples

      df = Explorer.Datasets.fossil_fuels()
      Kino.Explorer.new(df)

  """

  alias Explorer.DataFrame
  alias Explorer.Series
  require Explorer.DataFrame

  @behaviour Kino.Table

  @type t :: Kino.JS.Live.t()

  @date_types [
    :date,
    {:datetime, :nanosecond},
    {:datetime, :microsecond},
    {:datetime, :millisecond}
  ]

  @legacy_numeric_types [:float, :integer]

  @doc """
  Creates a new kino displaying a given data frame or series.
  """
  @spec new(DataFrame.t() | Series.t(), keyword()) :: t()
  def new(data, opts \\ [])

  def new(%DataFrame{} = df, opts) do
    name = Keyword.get(opts, :name, "DataFrame")
    Kino.Table.new(__MODULE__, {df, name}, export: fn state -> {"text", inspect(state.df)} end)
  end

  def new(%Series{} = s, opts) do
    name = Keyword.get(opts, :name, "Series")
    column_name = name |> String.replace(" ", "_") |> String.downcase() |> String.to_atom()
    df = DataFrame.new([{column_name, s}])
    Kino.Table.new(__MODULE__, {df, name}, export: fn state -> {"text", inspect(state.df[0])} end)
  end

  @impl true
  def init({df, name}) do
    lazy = lazy?(df)
    groups = df.groups
    df = DataFrame.ungroup(df)
    total_rows = if !lazy, do: DataFrame.n_rows(df)
    columns = columns(df, lazy, groups)
    info = info(columns, lazy, name)

    {:ok, info, %{df: df, total_rows: total_rows, columns: columns, groups: groups}}
  end

  @impl true
  def get_data(rows_spec, state) do
    {records, total_rows, summaries} = get_records(state, rows_spec)
    columns = Enum.map(state.columns, &%{&1 | summary: summaries[&1.key]})
    data = records_to_data(columns, records)
    {:ok, %{columns: columns, data: {:columns, data}, total_rows: total_rows}, state}
  end

  @impl true
  def export_data(%{df: df}, "CSV") do
    data = df |> DataFrame.collect() |> DataFrame.dump_csv!()
    %{data: data, extension: ".csv", type: "text/csv"}
  end

  def export_data(%{df: df}, "NDJSON") do
    data = df |> DataFrame.collect() |> DataFrame.dump_ndjson!()
    %{data: data, extension: ".ndjson", type: "application/x-ndjson"}
  end

  def export_data(%{df: df}, "Parquet") do
    data = df |> DataFrame.collect() |> DataFrame.dump_parquet!()
    %{data: data, extension: ".parquet", type: "application/x-parquet"}
  end

  defp columns(df, lazy, groups) do
    dtypes = DataFrame.dtypes(df)
    sample_data = df |> DataFrame.head(1) |> DataFrame.collect() |> DataFrame.to_columns()
    summaries = if !lazy, do: summaries(df, groups)

    for name <- df.names, dtype = Map.fetch!(dtypes, name) do
      %{
        key: name,
        label: to_string(name),
        type: type_of(dtype, sample_data[name]),
        summary: summaries[name]
      }
    end
  end

  defp info(columns, lazy, name) do
    name = if lazy, do: "Lazy - #{name}", else: name
    has_list_column? = Enum.any?(columns, fn x -> x.type == "list" end)
    formats = if has_list_column?, do: ["NDJSON", "Parquet"], else: ["CSV", "NDJSON", "Parquet"]

    %{name: name, features: [:export, :pagination, :sorting], export: %{formats: formats}}
  end

  defp get_records(%{df: df, groups: groups}, rows_spec) do
    lazy = lazy?(df)
    df = order_by(df, rows_spec[:order])
    total_rows = if !lazy, do: DataFrame.n_rows(df)
    summaries = if total_rows && total_rows > 0, do: summaries(df, groups)
    df = DataFrame.slice(df, rows_spec.offset, rows_spec.limit)
    records = df |> DataFrame.collect() |> DataFrame.to_columns()
    {records, total_rows, summaries}
  end

  defp order_by(df, nil), do: df

  defp order_by(df, %{key: column, direction: direction}) do
    DataFrame.sort_with(df, &[{direction, &1[column]}])
  end

  defp records_to_data(columns, records) do
    Enum.map(columns, fn column ->
      records |> Map.fetch!(column.key) |> Enum.map(&value_to_string(column.type, &1))
    end)
  end

  defp value_to_string("binary", value) do
    inspect_opts = Inspect.Opts.new([])
    if String.printable?(value, inspect_opts.limit), do: value, else: inspect(value)
  end

  defp value_to_string("list", value), do: inspect(value)
  defp value_to_string(_type, value), do: to_string(value)

  defp summaries(df, groups) do
    df_series = DataFrame.to_series(df)
    has_groups = length(groups) > 0

    for {column, series} <- df_series,
        type = if(numeric_type?(Series.dtype(series)), do: :numeric, else: :categorical),
        grouped = (column in groups) |> to_string(),
        nulls = Series.nil_count(series) |> to_string(),
        into: %{} do
      build_summary(type, column, series, has_groups, grouped, nulls)
    end
  end

  defp build_summary(:numeric, column, series, has_groups, grouped, nulls) do
    mean = Series.mean(series)
    mean = if is_float(mean), do: Float.round(mean, 2) |> to_string(), else: to_string(mean)
    min = Series.min(series) |> to_string()
    max = Series.max(series) |> to_string()
    keys = ["min", "max", "mean", "nulls"]
    values = [min, max, mean, nulls]

    keys = if has_groups, do: keys ++ ["grouped"], else: keys
    values = if has_groups, do: values ++ [grouped], else: values

    {column, %{keys: keys, values: values}}
  end

  defp build_summary(:categorical, column, series, has_groups, grouped, nulls) do
    # TODO: Remove this when possible
    # The main case that makes us need to use try/rescue here is when there are internal nils in a list
    # For example: Series.from_list([[1, 2], [2, nil]]) will break on most_frequent and unique
    # Null type is also a problem, but it only breaks on unique
    try do
      %{"counts" => top_freq, "values" => top} = most_frequent(series)
      top_freq = top_freq |> List.first() |> to_string()
      top = List.first(top) |> build_top()
      unique = series |> Series.distinct() |> Series.count() |> to_string()
      keys = ["unique", "top", "top freq", "nulls"]
      values = [unique, top, top_freq, nulls]

      keys = if has_groups, do: keys ++ ["grouped"], else: keys
      values = if has_groups, do: values ++ [grouped], else: values

      {column, %{keys: keys, values: values}}
    rescue
      _ -> {column, %{keys: [], values: []}}
    end
  end

  defp most_frequent(data) do
    data
    |> Series.frequencies()
    |> DataFrame.head(2)
    |> DataFrame.filter(Series.is_not_nil(values))
    |> DataFrame.head(1)
    |> DataFrame.to_columns()
  end

  defp type_of(dtype, _) when dtype in @date_types, do: "date"
  defp type_of(:boolean, _), do: "boolean"
  defp type_of(:string, [data]), do: type_of_sample(data)
  defp type_of(:binary, _), do: "binary"
  defp type_of({:list, _}, _), do: "list"
  defp type_of(dtype, _), do: if(numeric_type?(dtype), do: "number", else: "text")

  defp type_of_sample("http" <> _rest), do: "uri"
  defp type_of_sample(_), do: "text"

  defp numeric_type?({:s, _}), do: true
  defp numeric_type?({:u, _}), do: true
  defp numeric_type?({:f, _}), do: true
  # For backwards compatibility
  defp numeric_type?(other), do: other in @legacy_numeric_types

  defp lazy?(%DataFrame{data: %struct{}}), do: struct.lazy() == struct

  defp build_top(top) when is_list(top), do: inspect(top)
  defp build_top(top), do: to_string(top)
end
