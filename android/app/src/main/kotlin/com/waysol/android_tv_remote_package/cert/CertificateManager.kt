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

class CertificateManager(private val context: Context) {

    /**
     * Load DER certificate
     */
    fun loadDERCertificate(derPath: String): X509Certificate? {
        return try {
            val cf = CertificateFactory.getInstance("X.509")
            FileInputStream(derPath).use { fis ->
                cf.generateCertificate(fis) as X509Certificate
            }
        } catch (e: Exception) {
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
        return try {
            val keyStore = KeyStore.getInstance("PKCS12")
            FileInputStream(pkcs12Path).use { fis ->
                keyStore.load(fis, password.toCharArray())
            }
            keyStore
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Create SSL Context for mutual TLS authentication
     */
    fun createSSLContext(pkcs12Path: String, password: String = ""): SSLContext? {
        return try {
            val keyStore = loadPKCS12KeyStore(pkcs12Path, password) ?: return null

            val kmf = KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm())
            kmf.init(keyStore, password.toCharArray())

            val trustAllCerts = arrayOf<TrustManager>(object : X509TrustManager {
                override fun checkClientTrusted(chain: Array<X509Certificate>, authType: String) {}
                override fun checkServerTrusted(chain: Array<X509Certificate>, authType: String) {}
                override fun getAcceptedIssuers(): Array<X509Certificate> = arrayOf()
            })

            val sslContext = SSLContext.getInstance("TLSv1.2")
            sslContext.init(kmf.keyManagers, trustAllCerts, java.security.SecureRandom())

            sslContext
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Get private key from KeyStore
     */
    fun getPrivateKey(pkcs12Path: String, password: String = ""): PrivateKey? {
        return try {
            val keyStore = loadPKCS12KeyStore(pkcs12Path, password) ?: return null
            val alias = keyStore.aliases().nextElement()
            keyStore.getKey(alias, password.toCharArray()) as PrivateKey
        } catch (e: Exception) {
            null
        }
    }
}
