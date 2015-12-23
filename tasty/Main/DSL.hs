module Main.DSL where

import Main.Prelude
import qualified Hasql.Connection as HC
import qualified Hasql.Query as HQ
import qualified Hasql.Encoders as HE
import qualified Hasql.Decoders as HD
import qualified Hasql.Session


newtype Session a =
  Session (ReaderT HC.Connection (EitherT Hasql.Session.Error IO) a)
  deriving (Functor, Applicative, Monad, MonadIO)

data SessionError =
  ConnectionError (Maybe ByteString) |
  SessionError (Hasql.Session.Error)
  deriving (Show, Eq)

session :: Session a -> IO (Either SessionError a)
session (Session impl) =
  runEitherT $ acquire >>= \connection -> use connection <* release connection
  where
    acquire =
      EitherT $ fmap (mapLeft ConnectionError) $ HC.acquire settings
      where
        settings =
          HC.settings host port user password database
          where
            host = "localhost"
            port = 5432
            user = "postgres"
            password = ""
            database = "postgres"
    use connection =
      bimapEitherT SessionError id $
      runReaderT impl connection
    release connection =
      lift $ HC.release connection

query :: a -> HQ.Query a b -> Session b
query params query =
  Session $ ReaderT $ \connection -> EitherT $ flip Hasql.Session.run connection $ Hasql.Session.query params query
