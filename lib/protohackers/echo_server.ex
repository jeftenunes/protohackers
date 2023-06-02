defmodule Protohackers.EchoServer do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, :no_state)
  end

  @impl true
  def init(:no_state) do
    IO.puts("Starting echo server")
    accept()
  end

  defp accept() do
    port = 4001
    listen_opts = [:binary, packet: :line, active: false, reuseaddr: true]

    case :gen_tcp.listen(port, listen_opts) do
      {:ok, socket} ->
        IO.puts("Listening - port #{port}")
        echo_server_loop(socket)

      {:error, reason} ->
        IO.puts("Your server's bugged. Fix it, idiot. Reason: #{reason}")
        {:stop, reason}
    end
  end

  defp echo_server_loop(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    serve(client)
    echo_server_loop(socket)
  end

  defp serve(socket) do
    socket
    |> recv()
    |> tcp_send(socket)

    serve(socket)
  end

  defp recv(socket) do
    {:ok, data} = :gen_tcp.recv(socket, 0)
    IO.puts("RECEIVED REQUEST | data #{data}")
    data
  end

  defp tcp_send(data, socket) do
    IO.puts("ECHOING")
    :gen_tcp.send(socket, data)
  end
end
