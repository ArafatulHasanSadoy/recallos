/// Play receipts for tests, made with openssl rather than by hand.
///
/// A throwaway 2048-bit RSA key pair stands in for the key Play Console
/// holds: [testPlayKey] is its public half, encoded as Play Console prints
/// one, and every signature here is SHA1withRSA, as Play signs. Made with:
///
///     openssl genrsa -out key.pem 2048
///     openssl rsa -in key.pem -pubout -outform DER | base64
///     printf '%s' "$json" | openssl dgst -sha1 -sign key.pem | base64
///
/// [otherPlayKey] is a second key, for "signed, but not by Google".
library;

const String testPlayKey =
    'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA17WWG1O94gYWKM7EwZGdUyyzDu'
    'YOTtdvOmKoxNVbZn4euYmXh7+Y+1U39iqAK3C7jddErTd6Je4gsbDs/h+C4qo9/aYtfD/0'
    'Igs6IAB8Rh9wjjY2miZi8QG7xDuYQPbM/P4N8vtM6Psj5XVhtHgZa3CX6wAiSmw9S3x63a'
    'qzdGgxwL+AvO/QiQLtp7IKzpVh+bwXJGQfAj74NdrEsuGq5D8WnIA/e56GsL9gZ1BNayT5'
    '9meKGpUX9N3etYRW03GxpqaEjYNX6SNbq5VHOJmXdkYV5CyJBsXuSwyICxYP+1cOgeEMUl'
    'UwoGA/S49MMEkK8DPGN9U0Kv7sw40Iz2vLHQIDAQAB';

const String otherPlayKey =
    'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA9gKY/JDU2SEvFrycDV56M7QCr+'
    'aFpHmD8J45XQTtZNb1u3LU3aOCLLTVPe7+HoQFF4/p3ABsoMu+PInBNSGtT8BFIWQxW6Dw'
    '8mPHg83MnCfAttLEZaDiOewFH/hXPbgWB5/PjLk1sDPEEeAe0wbfeUE13AWzPedFZzI/4H'
    'Q9n269is2QltKmYDP1dCKAt3cO2GG8pw0joBMjoVKGl4tJgRIMp/4o3CMSY5lumuxCV1ZM'
    'vRaFUj6qPzfHiK5Nd/CAoMPIckMxroTDisSuPwIo6nA2ibURMZ1SLbdFQvj2lD2qkgZNz7'
    'LOw3Zq7BsFNRTudZVAzSZkKg5axl0SB3ejlQIDAQAB';

/// A completed purchase of RecallOS Plus.
const String plusReceipt =
    '{"orderId":"GPA.3300-0000-0000-00000","packageName":"com.recallos.recallos","productId":"recallos_plus","purchaseTime":1791100000000,"purchaseState":0,"purchaseToken":"test-token-1","quantity":1,"acknowledged":false}';
const String plusSignature =
    'xrvaUKF6xFAV8sDHuEsOrP98POsC0vpIXxyFo/xAoHDZzU4QGqckWOXZf0H22YX2zKFTxi'
    'fKpC+5ept6ZOSM/XEn33b9u8hzqQu9IJtZQc0XpC+9itcOaRZDe47AnDWBT/UYyZJMNolh'
    '4oYpACDABA8nNzog6/ZkqqOkcj6LM3yJtBblcDpRCbNyp45tnxd5zLnR3GeDImVLhDiFSb'
    'QH8hLETM8oPozLEcbUvkVsBmQ9y9TUepngmu1heHS4Lt3E6/zxhOrEcHaQ3myb7IzQw/Zw'
    'vvPxrnxbhA6Irv9xXEcWsHxsygpBtgxdtfrhaR8C4qTzi1BFOrnurny+OYlhJw==';

/// The same receipt, signed by a key that is not the app's.
const String plusSignatureWrongKey =
    'FZobjw7t0LKHE0VPiizxDo19GELnEP1h6gj+bPt/ZYDeIP8U8Fg0m9Qiqb9V1WLPAZVvQb'
    'YjTp2Dr6Khs4/ZyZqTpfCQXCl4l/YnO4jxPKQqKWlDpKXxbcnbkR/K9qAhLCIvsOXV85Er'
    'PdZZSZbvjas2exJ/zOsbVWGWQ8YZyOhl6gG7loOb/o6u3ns/c1LpCAuOBPFwqeWh31Koph'
    '7mnLKkogujwvoBkv9rrqpPwi0DVaJGhgtlNvvoqB65wXYSZkikHoxSB1dY9ERkHj+Zydss'
    'UyIwHFYQ06k7DOSSIiIf7fNRGwqBN6fgIo4pZmja+RzEFB5qaFutgnjYPUkFSA==';

/// RecallOS Plus, bought but waiting on payment (`purchaseState` 4).
const String pendingReceipt =
    '{"orderId":"GPA.3300-0000-0000-00001","packageName":"com.recallos.recallos","productId":"recallos_plus","purchaseTime":1791100000000,"purchaseState":4,"purchaseToken":"test-token-2","quantity":1,"acknowledged":false}';
const String pendingSignature =
    'SfdqKrmr25fc2fkAGgvkvfLzoUsZfuC97RD/yBbMvMbaRcywid8bZkroMdo0DE3aoWrqua'
    'aPhdxQtQiWHzkM+Fh8E04B+J77DcZzQlrU22XvyRwqgAvqJs2sNZM3BBESFWF8fd0ehhsU'
    '/53cQ8jnz1SSm+YB5MPl52g1mqmwGDtU+qAXJUwDLTeYKNcaV2WiO1I7XbcRZCcQoDn2l2'
    'qYP7XdletoMCn7reIf/JocfmjBN9fVkbTt6EiEZJK+MDEkQM+ZfjLLUJ9acwamWgE7zbNk'
    'ZtgWJCufLAhkLjrK+4euxy5SqYDpdX+X1ebiVdGQIEs7cdUYjkuHTzt+Zv+6Cg==';

/// A genuine receipt for something that is not Plus.
const String otherProductReceipt =
    '{"orderId":"GPA.3300-0000-0000-00002","packageName":"com.recallos.recallos","productId":"some_other_thing","purchaseTime":1791100000000,"purchaseState":0,"purchaseToken":"test-token-3","quantity":1,"acknowledged":false}';
const String otherProductSignature =
    'Q3ClAQcMgowPM43cNvWkTOHBRiuhDHY5xLy8WGnYNcOXEK2WNuwvZeJRCNI97/+whbP9Yt'
    'BMXr1ZQ1Tm8JWI/6k2ULq4udNiip5XlfcfnbEdwaLfg5QAsnGOCLqQxi7c55R6eWQq2Rll'
    'E2LxGUEMTzQn2j8PAdK5tQE7uCnJ0E3OkqXoUkp2PqqHb+kWSoD4s7DDR71NP7pedyozN1'
    'j8eEc4A6sXedYOtwHNCOIKhkMrz/ioK2djjUoEM/e2sxxKlas967ZF72dsFMMU3ebiDKy1'
    'VzlsTtk3NX3Ie/fhA8YZxcH4Qbermorh0rGRlZnYh4qZQ2V91JWbfauvnInNfQ==';
