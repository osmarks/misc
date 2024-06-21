{-# LANGUAGE TemplateHaskell #-}

module StringGroup where

import Test.QuickCheck

data SChar = P Char | N Char deriving (Eq, Ord, Show)
newtype SString = SString [SChar] deriving (Eq, Ord, Show)

instance Arbitrary SChar where
    arbitrary = oneof [fmap P arbitrary, fmap N arbitrary]

instance Arbitrary SString where
    arbitrary = fmap (<> mempty) $ sized $ fmap SString . vector

instance Semigroup SString where
    (SString xs) <> (SString ys) = SString (reverse $ go zs [])
        where
            zs = xs <> ys
            go [] acc = acc
            go ((N x):xs) ((P y):ys)
                | x == y = go xs ys
                | otherwise = go xs (N x:P y:ys)
            go ((P x):xs) ((N y):ys)
                | x == y = go xs ys
                | otherwise = go xs (P x:N y:ys)
            go (x:xs) acc = go xs (x:acc)

instance Monoid SString where
    mempty = SString []

positive = SString . map P
negateSChar (P x) = N x
negateSChar (N x) = P x
inverse (SString s) = SString $ reverse $ map negateSChar s

prop_associative :: SString -> SString -> SString -> Bool
prop_associative xs ys zs = (xs <> ys) <> zs == xs <> (ys <> zs)
prop_leftIdentity :: SString -> Bool
prop_leftIdentity xs = mempty <> xs == xs
prop_rightIdentity ::  SString -> Bool
prop_rightIdentity xs = xs <> mempty == xs
prop_leftInverse xs = inverse xs <> xs == mempty
prop_rightInverse xs = xs <> inverse xs == mempty

return []
tests = $forAllProperties $
  quickCheckWithResult (stdArgs {maxSuccess = 10000})

main = do
    let x = positive "hello world!"
    let y = inverse $ positive " world!"
    print (x <> y)
    
    tests