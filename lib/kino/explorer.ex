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

  @doc """
  Creates a new kino displaying a given data frame or series.
  """
  @spec new(DataFrame.t() | Series.t(), keyword()) :: t()
  def new(data, opts \\ [])

  def new(%DataFrame{} = df, opts) do
    name = Keyword.get(opts, :name, "DataFrame")
    Kino.Table.new(__MODULE__, {df, name})
  end

  def new(%Series{} = s, opts) do
    name = Keyword.get(opts, :name, "Series")
    column_name = name |> String.replace(" ", "_") |> String.downcase() |> String.to_atom()
    df = DataFrame.new([{column_name, s}])
    Kino.Table.new(__MODULE__, {df, name})
  end

  @impl true
  def init({df, name}) do
    lazy = lazy?(df)
    groups = df.groups
    df = DataFrame.ungroup(df)
    total_rows = if !lazy, do: DataFrame.n_rows(df)
    dtypes = DataFrame.dtypes(df)
    sample_data = df |> DataFrame.head(1) |> DataFrame.collect() |> DataFrame.to_columns()
    summaries = if !lazy, do: summaries(df, groups)
    name = if lazy, do: "Lazy - #{name}", else: name

    columns =
      for name <- df.names, dtype = Map.fetch!(dtypes, name) do
        %{
          key: name,
          label: to_string(name),
          type: type_of(dtype, sample_data[name]),
          summary: summaries[name]
        }
      end

    info = %{
      name: name,
      features: [:export, :pagination, :sorting],
      export: [:csv]
    }

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
  def export_data(%{df: df}, _format) do
    data = DataFrame.dump_csv!(df)
    %{data: data, extension: "csv", type: "text/csv"}
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
    DataFrame.arrange_with(df, &[{direction, &1[column]}])
  end

  defp records_to_data(columns, records) do
    Enum.map(columns, fn column -> Map.fetch!(records, column.key) |> Enum.map(&to_string/1) end)
  end

  defp summaries(df, groups) do
    df_series = DataFrame.to_series(df)
    has_groups = length(groups) > 0

    for {column, series} <- df_series,
        summary_type = summary_type(series),
        grouped = (column in groups) |> to_string(),
        nulls = Series.nil_count(series) |> to_string(),
        into: %{} do
      if summary_type == :numeric do
        mean = Series.mean(series)
        mean = if is_float(mean), do: Float.round(mean, 2) |> to_string(), else: to_string(mean)
        min = Series.min(series) |> to_string()
        max = Series.max(series) |> to_string()
        keys = ["min", "max", "mean", "nulls"]
        values = [min, max, mean, nulls]

        keys = if has_groups, do: keys ++ ["grouped"], else: keys
        values = if has_groups, do: values ++ [grouped], else: values

        {column, %{keys: keys, values: values}}
      else
        %{"counts" => top_freq, "values" => top} = most_frequent(series)
        top_freq = top_freq |> List.first() |> to_string()
        top = List.first(top) |> to_string()
        unique = count_unique(series)
        keys = ["unique", "top", "top freq", "nulls"]
        values = [unique, top, top_freq, nulls]

        keys = if has_groups, do: keys ++ ["grouped"], else: keys
        values = if has_groups, do: values ++ [grouped], else: values

        {column, %{keys: keys, values: values}}
      end
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

  defp summary_type(data) do
    if Series.dtype(data) in [:float, :integer], do: :numeric, else: :categorical
  end

  defp count_unique(data) do
    data |> Series.distinct() |> Series.count() |> to_string()
  end

  defp type_of(dtype, _) when dtype in [:integer, :float], do: "number"
  defp type_of(dtype, _) when dtype in [:date, :datetime], do: "date"
  defp type_of(:boolean, _), do: "boolean"
  defp type_of(:string, [data]), do: type_of_sample(data)
  defp type_of(_, _), do: "text"

  defp type_of_sample("http" <> _rest), do: "uri"
  defp type_of_sample(_), do: "text"

  def lazy?(%DataFrame{data: %struct{}}), do: struct.lazy() == struct
end
