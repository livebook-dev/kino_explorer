defmodule Kino.Explorer do
  @moduledoc """
  A kino for interactively viewing `Explorer.DataFrame`.

  ## Examples

      df = Explorer.Datasets.fossil_fuels()
      Kino.Explorer.new(df)

  """

  @behaviour Kino.Table

  @type t :: Kino.JS.Live.t()

  @doc """
  Creates a new kino displaying given data frame.
  """
  @spec new(Explorer.DataFrame.t(), keyword()) :: t()
  def new(df, opts \\ []) do
    name = Keyword.get(opts, :name, "DataFrame")
    Kino.Table.new(__MODULE__, {df, name})
  end

  @impl true
  def init({df, name}) do
    total_rows = Explorer.DataFrame.n_rows(df)
    dtypes = Explorer.DataFrame.dtypes(df)
    sample_data = df |> Explorer.DataFrame.head(1) |> Explorer.DataFrame.to_columns()
    summaries = summaries(df)

    columns =
      Enum.map(dtypes, fn {name, dtype} ->
        %{
          key: name,
          label: to_string(name),
          type: type_of(dtype, sample_data[name]),
          summary: summaries[name]
        }
      end)

    info = %{name: name, features: [:pagination, :sorting]}

    {:ok, info, %{df: df, total_rows: total_rows, columns: columns}}
  end

  @impl true
  def get_data(rows_spec, state) do
    {records, total_rows, summaries} = get_records(state.df, rows_spec)
    columns = Enum.map(state.columns, &%{&1 | summary: summaries[&1.key]})
    rows = Enum.map(records, &record_to_row/1)
    {:ok, %{columns: columns, rows: rows, total_rows: total_rows}, state}
  end

  defp get_records(df, rows_spec) do
    df =
      df
      |> order_by(rows_spec.order, rows_spec[:order_by])
      |> filter_by(rows_spec.filter, rows_spec[:filter_by], rows_spec.filter_value)

    total_rows = Explorer.DataFrame.n_rows(df)
    summaries = if total_rows > 0, do: summaries(df)
    df = Explorer.DataFrame.slice(df, rows_spec.offset, rows_spec.limit)
    {col_names, lists} = df |> Explorer.DataFrame.to_columns() |> Enum.unzip()
    records = Enum.zip_with(lists, fn row -> Enum.zip(col_names, row) end)
    {records, total_rows, summaries}
  end

  defp order_by(df, order, order_by) do
    if order_by, do: Explorer.DataFrame.arrange_with(df, &[{order, &1[order_by]}]), else: df
  end

  defp filter_by(df, filter, filter_by, value) do
    type = Explorer.DataFrame.dtypes(df) |> Map.get(filter_by)
    value = if type in [:date, :datetime], do: to_date(type, value), else: value

    if filter_by && value,
      do: Explorer.DataFrame.filter_with(df, filter_by(filter, filter_by, value)),
      else: df
  end

  defp to_date(type, value) do
    case DateTime.from_iso8601(value) do
      {:ok, date, _} -> if type == :date, do: DateTime.to_date(date), else: date
      _ -> nil
    end
  end

  defp record_to_row(record) do
    fields = Map.new(record, fn {col_name, value} -> {col_name, to_string(value)} end)
    %{fields: fields}
  end

  defp summaries(df) do
    df_series = Explorer.DataFrame.to_series(df)

    for {column, series} <- df_series,
        summary_type = summary_type(series),
        nulls = Explorer.Series.nil_count(series) |> to_string(),
        into: %{} do
      if summary_type == :numeric do
        mean = Explorer.Series.mean(series) |> Float.round(2) |> to_string()
        min = Explorer.Series.min(series) |> to_string()
        max = Explorer.Series.max(series) |> to_string()
        {column, %{min: min, max: max, mean: mean, nulls: nulls}}
      else
        %{"counts" => [top_freq], "values" => [top]} = most_frequent(series)

        {column,
         %{nulls: nulls, top: top, top_freq: to_string(top_freq), unique: count_unique(series)}}
      end
    end
  end

  defp most_frequent(data) do
    data
    |> Explorer.Series.frequencies()
    |> Explorer.DataFrame.head(1)
    |> Explorer.DataFrame.to_columns()
  end

  defp summary_type(data) do
    if Explorer.Series.dtype(data) in [:float, :integer], do: :numeric, else: :categorical
  end

  defp count_unique(data) do
    data |> Explorer.Series.distinct() |> Explorer.Series.count() |> to_string()
  end

  defp type_of(dtype, _) when dtype in [:integer, :float], do: "number"
  defp type_of(dtype, _) when dtype in [:date, :datetime], do: "date"
  defp type_of(:string, [data]), do: type_of_sample(data)
  defp type_of(_, _), do: "text"

  defp type_of_sample("http" <> _rest), do: "uri"
  defp type_of_sample(_), do: "text"

  defp filter_by(:less, column, value), do: &Explorer.Series.less(&1[column], value)
  defp filter_by(:less_eq, column, value), do: &Explorer.Series.less_equal(&1[column], value)
  defp filter_by(:equal, column, value), do: &Explorer.Series.equal(&1[column], value)
  defp filter_by(:not_equal, column, value), do: &Explorer.Series.not_equal(&1[column], value)

  defp filter_by(:greater_eq, column, value),
    do: &Explorer.Series.greater_equal(&1[column], value)

  defp filter_by(:greater, column, value), do: &Explorer.Series.greater(&1[column], value)
end
