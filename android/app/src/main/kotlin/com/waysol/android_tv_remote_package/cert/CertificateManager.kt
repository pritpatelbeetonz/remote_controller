package com.waysol.android_tv_remote_package.cert

import android.content.Context
import java.io.FileInputStream
import java.security.KeyStore
import java.security.PrivateKey
import java.security.cert.CertificateFactory
import java.security.cert.X509Certificate
import javax.net.ssl.KeyManagerFactory
import javax.net.ssl.SSLContext
import javax.net.ssl.TrustManager
import javax.net.ssl.X509TrustManager
import org.bouncycastle.jce.provider.BouncyCastleProvider
import com.waysol.android_tv_remote_package.util.Logger
import com.waysol.android_tv_remote_package.util.Constants

class CertificateManager(private val context: Context) {

    /**
     * Load DER certificate
     */
    fun loadDERCertificate(derPath: String): X509Certificate? {
        Logger.i(Constants.TAG_CERTIFICATE, "Loading DER certificate from Path: $derPath")
        return try {
            val cf = CertificateFactory.getInstance("X.509")
            val cert = FileInputStream(derPath).use { fis ->
                cf.generateCertificate(fis) as X509Certificate
            }
            Logger.i(Constants.TAG_CERTIFICATE, "Certificate loaded successfully")
            cert
        } catch (e: Exception) {
            Logger.e(Constants.TAG_CERTIFICATE, "Certificate loading failed\nPath: $derPath", e)
            null
        }
    }

    /**
     * Load PKCS#12 KeyStore
     */
    fun loadPKCS12KeyStore(
        pkcs12Path: String,
        password: String = ""
    ): KeyStore? {
        Logger.i(Constants.TAG_CERTIFICATE, "Loading PKCS12\nPath: $pkcs12Path\nPassword supplied: ${password.isNotEmpty()}")
        return try {
            val keyStore = KeyStore.getInstance("PKCS12")
            FileInputStream(pkcs12Path).use { fis ->
                keyStore.load(fis, password.toCharArray())
            }
            val aliases = keyStore.aliases()
            if (aliases.hasMoreElements()) {
                val alias = aliases.nextElement()
                Logger.i(Constants.TAG_CERTIFICATE, "Alias found: $alias")
            } else {
                Logger.w(Constants.TAG_CERTIFICATE, "No alias found in KeyStore")
            }
            keyStore
        } catch (e: Exception) {
            Logger.e(Constants.TAG_CERTIFICATE, "Certificate loading failed\nPath: $pkcs12Path", e)
            null
        }
    }

    /**
     * Create SSL Context for mutual TLS authentication
     */
    fun createSSLContext(pkcs12Path: String, password: String = ""): SSLContext? {
        Logger.i(Constants.TAG_CERTIFICATE, "Creating SSLContext for PKCS12 path: $pkcs12Path")
        return try {
            java.security.Security.addProvider(BouncyCastleProvider())
            val keyStore = loadPKCS12KeyStore(pkcs12Path, password) ?: throw Exception("KeyStore could not be loaded")

            val kmf = KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm())
            kmf.init(keyStore, password.toCharArray())

            val trustAllCerts = arrayOf<TrustManager>(object : X509TrustManager {
                override fun checkClientTrusted(chain: Array<X509Certificate>, authType: String) {}
                override fun checkServerTrusted(chain: Array<X509Certificate>, authType: String) {}
                override fun getAcceptedIssuers(): Array<X509Certificate> = arrayOf()
            })

            val sslContext = SSLContext.getInstance("TLSv1.2")
            sslContext.init(kmf.keyManagers, trustAllCerts, java.security.SecureRandom())

            Logger.i(Constants.TAG_CERTIFICATE, "SSLContext created successfully")
            sslContext
        } catch (e: Exception) {
            Logger.e(Constants.TAG_CERTIFICATE, "SSLContext creation failed", e)
            null
        }
    }

    /**
     * Get private key from KeyStore
     */
    fun getPrivateKey(pkcs12Path: String, password: String = ""): PrivateKey? {
        Logger.i(Constants.TAG_CERTIFICATE, "Loading private key from $pkcs12Path")
        return try {
            val keyStore = loadPKCS12KeyStore(pkcs12Path, password) ?: throw Exception("KeyStore could not be loaded")
            val alias = keyStore.aliases().nextElement()
            val key = keyStore.getKey(alias, password.toCharArray()) as PrivateKey
            Logger.i(Constants.TAG_CERTIFICATE, "Private key loaded successfully")
            key
        } catch (e: Exception) {
            Logger.e(Constants.TAG_CERTIFICATE, "Private key loading failed", e)
            null
        }
    }
}
