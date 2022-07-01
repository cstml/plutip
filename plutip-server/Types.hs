module Types
  ( AppM(AppM)
  , ClusterStartupFailureReason
    ( ClusterIsRunningAlready
    , NegativeLovelaces
    , NodeConfigNotFound
    )
  , Env(Env, status, options)
  , ErrorMessage
  , Lovelace(unLovelace)
  , PlutipServerError(PlutipServerError)
  , PrivateKey
  , ServerOptions(ServerOptions, nodeLogs, port)
  , StartClusterRequest(StartClusterRequest, keysToGenerate)
  , StartClusterResponse
    ( ClusterStartupSuccess
    , ClusterStartupFailure
    , keysDirectory
    , nodeSocketPath
    , privateKeys
    , publicKeys
    , nodeConfigPath
    )
  , StopClusterRequest(StopClusterRequest)
  , StopClusterResponse(StopClusterSuccess, StopClusterFailure)
  )
where

import Control.Monad.Catch (MonadThrow, Exception)
import Control.Monad.Reader (ReaderT, MonadReader)
import Control.Monad.IO.Class (MonadIO)
import Data.Aeson (FromJSON, ToJSON, parseJSON)
import Data.Kind (Type)
import Data.Text (Text)
import GHC.Generics (Generic)
import Network.Wai.Handler.Warp (Port)
import Test.Plutip.Internal.Types (ClusterEnv)
import UnliftIO.STM (TVar)
import Test.Plutip.Internal.LocalCluster (ClusterStatus(..))
import Control.Concurrent.MVar (MVar)
import Test.Plutip.Internal.BotPlutusInterface.Wallet (BpiWallet)

-- TVar is used for signaling by 'startCluster'/'stopCluster' (STM is used
-- for blocking).
-- MVar is used by plutip-server to store current TVar (we allow maximum of one
-- cluster at any given moment).
-- This MVar is used by start/stop handlers.
-- The payload of ClusterStatus is irrelevant.
type ClusterStatusRef = MVar (TVar (ClusterStatus (ClusterEnv, [BpiWallet])))

data Env = Env
  { status :: ClusterStatusRef
  , options :: ServerOptions
  }

data ServerOptions = ServerOptions
  { port :: Port
  , nodeLogs :: Maybe FilePath
  }
  deriving stock (Generic)

newtype AppM (a :: Type) = AppM (ReaderT Env IO a)
  deriving newtype
    ( Functor
    , Applicative
    , Monad
    , MonadIO
    , MonadReader Env
    , MonadThrow
    )

data PlutipServerError
  = PlutipServerError
  deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

instance Exception PlutipServerError

type ErrorMessage = Text

newtype Lovelace = Lovelace { unLovelace :: Integer }
  deriving stock (Show, Eq, Generic)
  deriving newtype (ToJSON, Num)

instance FromJSON Lovelace where
  parseJSON json = do
    value :: Integer <- parseJSON json
    if value < 0
      then fail "Lovelace value must not be negative"
      else pure $ Lovelace value

newtype StartClusterRequest
  = StartClusterRequest
    { keysToGenerate :: [[Lovelace]]
    -- ^ Lovelace amounts for each UTXO of each wallet
    }
  deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

-- CborHex
type PrivateKey = Text

data ClusterStartupFailureReason
  = ClusterIsRunningAlready
  | NegativeLovelaces
  | NodeConfigNotFound
  deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data StartClusterResponse
  = ClusterStartupFailure ClusterStartupFailureReason
  | ClusterStartupSuccess
    { privateKeys :: [PrivateKey]
    , publicKeys :: [Text]
    , nodeSocketPath :: FilePath
    , nodeConfigPath :: FilePath
    , keysDirectory :: FilePath
    }
  deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data StopClusterRequest = StopClusterRequest
  deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data StopClusterResponse = StopClusterSuccess | StopClusterFailure ErrorMessage
  deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)
