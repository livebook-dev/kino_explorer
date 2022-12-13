defimpl Kino.Render, for: Explorer.DataFrame do
  def to_livebook(df) do
    df |> Kino.Explorer.static() |> Kino.Render.to_livebook()
  end
end
