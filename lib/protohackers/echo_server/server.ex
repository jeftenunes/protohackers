defmodule Protohackers.EchoServer.Server do
  use GenServer

  defstruct [:socket, :supervisor]

  def start_link(_) do
    GenServer.start_link(__MODULE__, :no_state)
  end

  @impl true
  def init(:no_state) do
    IO.puts("Starting echo server")

    {:ok, supervisor} = Task.Supervisor.start_link(max_children: 10)

    port = 8080
    listen_opts = [:binary, active: false, reuseaddr: true, exit_on_close: false]

    case :gen_tcp.listen(port, listen_opts) do
      {:ok, socket} ->
        IO.puts("Listening - port #{port}")
        state = %__MODULE__{socket: socket, supervisor: supervisor}
        {:ok, state, {:continue, :accept}}

      {:error, reason} ->
        IO.puts("Your server's bugged. Fix it, idiot. Reason: #{reason}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_continue(:accept, %__MODULE__{socket: socket} = state) do
    case :gen_tcp.accept(socket) do
      {:ok, socket} ->
        Task.Supervisor.start_child(state.supervisor, fn -> connect(socket) end)
        {:noreply, state, {:continue, :accept}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  defp connect(socket) do
    case recv(socket, _buffer = "") do
      {:ok, data} ->
        IO.puts("SENDING DATA | #{inspect(data)}")
        :gen_tcp.send(socket, data)

      {:error, reason} ->
        IO.inspect(reason)
    end

    :gen_tcp.close(socket)
  end

  defp recv(socket, buffer) do
    case :gen_tcp.recv(socket, 0, 5_000) do
      {:ok, data} ->
        IO.puts("RECEIVED REQUEST | #{inspect(data)}")
        recv(socket, [buffer, data])

      {:error, :closed} ->
        {:ok, buffer}

      {:error, reason} ->
        IO.puts("Error receiving data. #{inspect(reason)}")
        {:error, reason}
    end
  end
end
