# In order to encode and decode messages, use the following example:
#
#     Protobuf.encode(%MyMessage{...})
      #=> <<...>>
#
#     Protobuf.decode(<<...>>, MyMessage)
      #=> %MyMessage{...}
#     Protobuf.decode(<<"bad data">>, MyMessage)
      #=> ** (Protobuf.DecodeError) ...
#

defmodule Proto.Message.Type do
  @moduledoc false
  use Protobuf, enum: true, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :NETWORK_MESSAGE, 0
  field :PROC_REGISTRATION, 1
  field :PROC_INITIALIZE_SYSTEM, 2
  field :PROC_DESTROY_SYSTEM, 3
  field :APP_BROADCAST, 4
  field :APP_VALUE, 5
  field :APP_DECIDE, 6
  field :APP_PROPOSE, 7
  field :APP_READ, 8
  field :APP_WRITE, 9
  field :APP_READ_RETURN, 10
  field :APP_WRITE_RETURN, 11
  field :UC_DECIDE, 20
  field :UC_PROPOSE, 21
  field :EP_ABORT, 30
  field :EP_ABORTED, 31
  field :EP_DECIDE, 32
  field :EP_INTERNAL_ACCEPT, 33
  field :EP_INTERNAL_DECIDED, 34
  field :EP_INTERNAL_READ, 35
  field :EP_INTERNAL_STATE, 36
  field :EP_INTERNAL_WRITE, 37
  field :EP_PROPOSE, 38
  field :EC_INTERNAL_NACK, 40
  field :EC_INTERNAL_NEW_EPOCH, 41
  field :EC_START_EPOCH, 42
  field :BEB_BROADCAST, 50
  field :BEB_DELIVER, 51
  field :ELD_TIMEOUT, 60
  field :ELD_TRUST, 61
  field :NNAR_INTERNAL_ACK, 70
  field :NNAR_INTERNAL_READ, 71
  field :NNAR_INTERNAL_VALUE, 72
  field :NNAR_INTERNAL_WRITE, 73
  field :NNAR_READ, 74
  field :NNAR_READ_RETURN, 75
  field :NNAR_WRITE, 76
  field :NNAR_WRITE_RETURN, 77
  field :EPFD_INTERNAL_HEARTBEAT_REPLY, 80
  field :EPFD_INTERNAL_HEARTBEAT_REQUEST, 81
  field :EPFD_RESTORE, 82
  field :EPFD_SUSPECT, 83
  field :EPFD_TIMEOUT, 84
  field :PL_DELIVER, 90
  field :PL_SEND, 91
end

defmodule Proto.ProcessId do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :host, 1, type: :string
  field :port, 2, type: :int32
  field :owner, 3, type: :string
  field :index, 4, type: :int32
  field :rank, 5, type: :int32
end

defmodule Proto.Value do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :defined, 1, type: :bool
  field :v, 2, type: :int32
end

defmodule Proto.ProcRegistration do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :owner, 1, type: :string
  field :index, 2, type: :int32
end

defmodule Proto.ProcInitializeSystem do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :processes, 1, repeated: true, type: Proto.ProcessId
end

defmodule Proto.ProcDestroySystem do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3
end

defmodule Proto.AppBroadcast do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :value, 1, type: Proto.Value
end

defmodule Proto.AppValue do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :value, 1, type: Proto.Value
end

defmodule Proto.AppPropose do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :topic, 1, type: :string
  field :value, 2, type: Proto.Value
end

defmodule Proto.AppDecide do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :value, 1, type: Proto.Value
end

defmodule Proto.AppRead do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :register, 1, type: :string
end

defmodule Proto.AppWrite do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :register, 1, type: :string
  field :value, 2, type: Proto.Value
end

defmodule Proto.AppReadReturn do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :register, 1, type: :string
  field :value, 2, type: Proto.Value
end

defmodule Proto.AppWriteReturn do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :register, 1, type: :string
end

defmodule Proto.UcPropose do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :value, 1, type: Proto.Value
end

defmodule Proto.UcDecide do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :value, 1, type: Proto.Value
end

defmodule Proto.EpAbort do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3
end

defmodule Proto.EpAborted do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :ets, 1, type: :int32
  field :valueTimestamp, 2, type: :int32
  field :value, 3, type: Proto.Value
end

defmodule Proto.EpPropose do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :value, 1, type: Proto.Value
end

defmodule Proto.EpDecide do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :ets, 1, type: :int32
  field :value, 2, type: Proto.Value
end

defmodule Proto.EpInternalRead do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3
end

defmodule Proto.EpInternalState do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :valueTimestamp, 1, type: :int32
  field :value, 2, type: Proto.Value
end

defmodule Proto.EpInternalWrite do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :value, 1, type: Proto.Value
end

defmodule Proto.EpInternalAccept do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3
end

defmodule Proto.EpInternalDecided do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :value, 1, type: Proto.Value
end

defmodule Proto.EcInternalNack do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3
end

defmodule Proto.EcStartEpoch do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :newTimestamp, 1, type: :int32
  field :newLeader, 2, type: Proto.ProcessId
end

defmodule Proto.EcInternalNewEpoch do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :timestamp, 1, type: :int32
end

defmodule Proto.BebBroadcast do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :message, 1, type: Proto.Message
end

defmodule Proto.BebDeliver do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :message, 1, type: Proto.Message
  field :sender, 2, type: Proto.ProcessId
end

defmodule Proto.EldTimeout do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3
end

defmodule Proto.EldTrust do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :process, 1, type: Proto.ProcessId
end

defmodule Proto.NnarRead do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3
end

defmodule Proto.NnarInternalRead do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :readId, 1, type: :int32
end

defmodule Proto.NnarInternalValue do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :readId, 1, type: :int32
  field :timestamp, 2, type: :int32
  field :writerRank, 3, type: :int32
  field :value, 4, type: Proto.Value
end

defmodule Proto.NnarInternalWrite do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :readId, 1, type: :int32
  field :timestamp, 2, type: :int32
  field :writerRank, 3, type: :int32
  field :value, 4, type: Proto.Value
end

defmodule Proto.NnarWrite do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :value, 1, type: Proto.Value
end

defmodule Proto.NnarInternalAck do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :readId, 1, type: :int32
end

defmodule Proto.NnarReadReturn do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :value, 1, type: Proto.Value
end

defmodule Proto.NnarWriteReturn do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3
end

defmodule Proto.EpfdTimeout do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3
end

defmodule Proto.EpfdInternalHeartbeatRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3
end

defmodule Proto.EpfdInternalHeartbeatReply do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3
end

defmodule Proto.EpfdSuspect do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :process, 1, type: Proto.ProcessId
end

defmodule Proto.EpfdRestore do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :process, 1, type: Proto.ProcessId
end

defmodule Proto.PlSend do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :destination, 1, type: Proto.ProcessId
  field :message, 2, type: Proto.Message
end

defmodule Proto.PlDeliver do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :sender, 1, type: Proto.ProcessId
  field :message, 2, type: Proto.Message
end

defmodule Proto.NetworkMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :senderHost, 1, type: :string
  field :senderListeningPort, 2, type: :int32
  field :message, 3, type: Proto.Message
end

defmodule Proto.Message do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :type, 1, type: Proto.Message.Type, enum: true
  field :messageUuid, 2, type: :string
  field :FromAbstractionId, 3, type: :string
  field :ToAbstractionId, 4, type: :string
  field :systemId, 5, type: :string
  field :networkMessage, 6, type: Proto.NetworkMessage
  field :procRegistration, 7, type: Proto.ProcRegistration
  field :procInitializeSystem, 8, type: Proto.ProcInitializeSystem
  field :procDestroySystem, 9, type: Proto.ProcDestroySystem
  field :appBroadcast, 10, type: Proto.AppBroadcast
  field :appValue, 11, type: Proto.AppValue
  field :appPropose, 12, type: Proto.AppPropose
  field :appDecide, 13, type: Proto.AppDecide
  field :appRead, 14, type: Proto.AppRead
  field :appWrite, 15, type: Proto.AppWrite
  field :appReadReturn, 16, type: Proto.AppReadReturn
  field :appWriteReturn, 17, type: Proto.AppWriteReturn
  field :ucDecide, 20, type: Proto.UcDecide
  field :ucPropose, 21, type: Proto.UcPropose
  field :epAbort, 30, type: Proto.EpAbort
  field :epAborted, 31, type: Proto.EpAborted
  field :epInternalAccept, 32, type: Proto.EpInternalAccept
  field :epDecide, 33, type: Proto.EpDecide
  field :epInternalDecided, 34, type: Proto.EpInternalDecided
  field :epPropose, 35, type: Proto.EpPropose
  field :epInternalRead, 36, type: Proto.EpInternalRead
  field :epInternalState, 37, type: Proto.EpInternalState
  field :epInternalWrite, 38, type: Proto.EpInternalWrite
  field :ecInternalNack, 41, type: Proto.EcInternalNack
  field :ecInternalNewEpoch, 42, type: Proto.EcInternalNewEpoch
  field :ecStartEpoch, 43, type: Proto.EcStartEpoch
  field :bebBroadcast, 50, type: Proto.BebBroadcast
  field :bebDeliver, 51, type: Proto.BebDeliver
  field :eldTimeout, 60, type: Proto.EldTimeout
  field :eldTrust, 61, type: Proto.EldTrust
  field :nnarInternalAck, 70, type: Proto.NnarInternalAck
  field :nnarInternalRead, 71, type: Proto.NnarInternalRead
  field :nnarInternalValue, 72, type: Proto.NnarInternalValue
  field :nnarInternalWrite, 73, type: Proto.NnarInternalWrite
  field :nnarRead, 74, type: Proto.NnarRead
  field :nnarReadReturn, 75, type: Proto.NnarReadReturn
  field :nnarWrite, 76, type: Proto.NnarWrite
  field :nnarWriteReturn, 77, type: Proto.NnarWriteReturn
  field :epfdTimeout, 80, type: Proto.EpfdTimeout
  field :epfdInternalHeartbeatRequest, 81, type: Proto.EpfdInternalHeartbeatRequest
  field :epfdInternalHeartbeatReply, 82, type: Proto.EpfdInternalHeartbeatReply
  field :epfdSuspect, 83, type: Proto.EpfdSuspect
  field :epfdRestore, 84, type: Proto.EpfdRestore
  field :plDeliver, 90, type: Proto.PlDeliver
  field :plSend, 91, type: Proto.PlSend
end
