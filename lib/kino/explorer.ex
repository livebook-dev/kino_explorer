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
  @spec new(Explorer.DataFrame.t()) :: t()
  def new(df) do
    Kino.Table.new(__MODULE__, {df})
  end

  @impl true
  def init({df}) do
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

    info = %{name: "DataFrame", features: [:pagination, :sorting]}

    {:ok, info, %{df: df, total_rows: total_rows, columns: columns}}
  end

  @impl true
  def get_data(rows_spec, state) do
    records = get_records(state.df, rows_spec)
    rows = Enum.map(records, &record_to_row/1)
    {:ok, %{columns: state.columns, rows: rows, total_rows: state.total_rows}, state}
  end

  defp get_records(df, rows_spec) do
    df =
      if order_by = rows_spec[:order_by] do
        Explorer.DataFrame.arrange_with(df, &[{rows_spec.order, &1[order_by]}])
      else
        df
      end

    df = Explorer.DataFrame.slice(df, rows_spec.offset, rows_spec.limit)

    {col_names, lists} = df |> Explorer.DataFrame.to_columns() |> Enum.unzip()

    Enum.zip_with(lists, fn row -> Enum.zip(col_names, row) end)
  end

  defp record_to_row(record) do
    fields = Map.new(record, fn {col_name, value} -> {col_name, to_string(value)} end)
    %{fields: fields}
  end

  defp summaries(df) do
    describe = describe(df)
    df_series = Explorer.DataFrame.to_series(df)

    for {column, [mean, min, max]} <- describe,
        series = Map.get(df_series, column),
        summary_type = summary_type(series),
        nulls = Explorer.Series.nil_count(series) |> to_string(),
        into: %{} do
      if summary_type == :numeric do
        mean = Float.round(mean, 2) |> to_string()
        {column, %{min: to_string(min), max: to_string(max), mean: mean, nulls: nulls}}
      else
        %{"counts" => [top_freq], "values" => [top]} = most_frequent(series)

        {column,
         %{nulls: nulls, top: top, top_freq: to_string(top_freq), unique: count_unique(series)}}
      end
    end
  end

  defp describe(data) do
    mean_idx = 1
    min_idx = 3
    max_idx = 7

    data
    |> Explorer.DataFrame.describe()
    |> Explorer.DataFrame.slice([mean_idx, min_idx, max_idx])
    |> Explorer.DataFrame.to_columns()
    |> Map.delete("describe")
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
end
