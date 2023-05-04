import unittest
from azure.identity import AzureAuthorityHosts

class TestIdentityImports(unittest.TestCase):

    def test_import(self):
        self.assertEqual(AzureAuthorityHosts.AZURE_PUBLIC_CLOUD, 'login.microsoftonline.com')

if __name__ == '__main__':
    unittest.main()