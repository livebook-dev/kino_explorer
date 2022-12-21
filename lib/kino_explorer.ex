defimpl Kino.Render, for: Explorer.DataFrame do
  def to_livebook(df) do
    df |> Kino.Explorer.new() |> Kino.Render.to_livebook()
  end
end

defimpl Kino.Render, for: Explorer.Series do
  def to_livebook(s) do
    s |> Kino.Explorer.new() |> Kino.Render.to_livebook()
  end
end
