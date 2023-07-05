defmodule Protohackers.PrimeTime.Server do
  use GenServer

  defstruct [:socket, :supervisor]

  def start_link(_) do
    GenServer.start_link(__MODULE__, :no_state)
  end

  @impl true
  def init(:no_state) do
    {:ok, supervisor} = Task.Supervisor.start_link(max_children: 10)

    port = 4001

    listen_opts = [
      ifaddr: {0, 0, 0, 0},
      mode: :binary,
      active: false,
      packet: :line,
      reuseaddr: true,
      buffer: 1024 * 100,
      exit_on_close: false
    ]

    case :gen_tcp.listen(port, listen_opts) do
      {:ok, socket} ->
        IO.puts("Listening - port #{port}")
        state = %__MODULE__{socket: socket, supervisor: supervisor}
        {:ok, state, {:continue, :accept}}

      {:error, reason} ->
        IO.puts("Cannot listen. Reason: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_continue(:accept, %__MODULE__{socket: socket, supervisor: supervisor} = state) do
    case :gen_tcp.accept(socket) do
      {:ok, socket} ->
        Task.Supervisor.start_child(supervisor, fn -> connect(socket) end)
        {:noreply, state, {:continue, :accept}}

      {:error, reason} ->
        IO.puts("Cannot accept. Reason: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  defp connect(socket) do
    case do_recv_until_closed(socket) do
      :ok ->
        :ok

      {:error, reason} ->
        IO.puts("Cannot connect. Reason: #{inspect(reason)}")
    end

    :gen_tcp.close(socket)
  end

  defp do_recv_until_closed(socket) do
    case :gen_tcp.recv(socket, 0, 5_000) do
      {:ok, data} ->
        case Jason.decode(data) do
          {:ok, %{"method" => "isPrime", "number" => number}} when is_number(number) ->
            inspect(number)
            response = %{"method" => "isPrime", "prime" => prime?(number)}

            :gen_tcp.send(socket, [Jason.encode!(response), ?\n])

            do_recv_until_closed(socket)
            :ok

          other ->
            IO.puts("Invalid request: #{inspect(other)}")
            :gen_tcp.send(socket, "malformed request\n")
            {:error, :malformed}
        end

        do_recv_until_closed(socket)

      {:error, :closed} ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp prime?(number) when is_float(number), do: false
  defp prime?(number) when number <= 1, do: false
  defp prime?(number) when number in [2, 3], do: true

  defp prime?(number),
    do: not Enum.any?(2..trunc(:math.sqrt(number)), &(rem(number, &1) == 0))
end
