#include <iostream>
#include <sodium.h>
#include <vector>
#include <string>

using namespace std;

#define BUF vector<unsigned char>

//Maybe use the AAD to store readonly metadata 
string to_base64(const BUF& data){
    auto max_len = sodium_base64_ENCODED_LEN(data.size(),sodium_base64_VARIANT_ORIGINAL);
    string b64(max_len,'\0');
    sodium_bin2base64(b64.data(),max_len,data.data(),data.size(),sodium_base64_VARIANT_ORIGINAL);
    b64.resize(strlen(b64.c_str()));
    return b64;
}

int main(){
    try{
        if(sodium_init() < 0){
            cerr << "Cannot initiate the libsodium." << endl;
            return 1;
        }
        if(crypto_aead_aes256gcm_is_available()){
            cout << "Your hardware supports crypto_aead_aes256gcm" << endl;
        }
        else{
            cout << "YOUR HARDWARE DOES NOT supports crypto_aead_aes256gcm" << endl;
            return 1;
        }
        BUF key(crypto_aead_aes256gcm_KEYBYTES);
        crypto_aead_aes256gcm_keygen(key.data());
        BUF nounce(crypto_aead_aes256gcm_NPUBBYTES);
        randombytes_buf(nounce.data(),nounce.size());
        
        string message = "the message";

        BUF cypher = BUF(message.size()+crypto_aead_aes256gcm_ABYTES);
        unsigned long long len = 0;
        int ret = crypto_aead_aes256gcm_encrypt(cypher.data(),&len,reinterpret_cast<const unsigned char*>(message.data()),message.size(),NULL,0,NULL,nounce.data(),key.data());
        if(ret != 0){
            cout << "Encryption failed" << endl;
            return 1;
        }
        cypher.resize(len);
        
        BUF decrypted = BUF(message.size()+crypto_aead_aes256gcm_ABYTES);
        ret = crypto_aead_aes256gcm_decrypt(decrypted.data(),&len,NULL,cypher.data(),cypher.size(),NULL,NULL,nounce.data(),key.data());

        if(ret != 0){
            cout << "fail to decrypt " << endl;
            return 1;
        }
        decrypted.resize(len);

        cout << "KEY: "<< to_base64(key) << endl;
        cout << "ENCRYPTED: " << to_base64(cypher) << endl;
        cout << "DECRYPTED: " <<  string(decrypted.begin(),decrypted.begin()+len) << endl;
        getchar();
    }
    catch(exception& ex){
        cerr << "Exception: " <<ex.what() << endl;
        return 1;
    }
}