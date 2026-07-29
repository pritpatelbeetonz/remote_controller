package com.waysol.android_tv_remote_package.cert

import android.content.Context
import java.io.File
import java.io.FileOutputStream
import java.math.BigInteger
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.PublicKey
import java.security.cert.Certificate
import java.security.cert.X509Certificate
import java.util.*
import org.bouncycastle.asn1.x500.X500Name
import org.bouncycastle.asn1.x509.BasicConstraints
import org.bouncycastle.asn1.x509.Extension
import org.bouncycastle.cert.jcajce.JcaX509CertificateConverter
import org.bouncycastle.cert.jcajce.JcaX509v3CertificateBuilder
import org.bouncycastle.jce.provider.BouncyCastleProvider
import org.bouncycastle.operator.ContentSigner
import org.bouncycastle.operator.jcajce.JcaContentSignerBuilder
import java.security.Security

class CertificateGenerator {

    init {
        // ⚠️ CRITICAL FIX 1: Remove Android's restricted native "BC" provider first
        Security.removeProvider(BouncyCastleProvider.PROVIDER_NAME)
        // Add the full, custom BouncyCastle jar package dependency instead
        Security.addProvider(BouncyCastleProvider())
    }

    /**
     * Generate self-signed certificate for Android TV pairing
     * Returns paths to generated DER and PKCS#12 files
     */
    fun generateCertificates(
        context: Context,
        certificateName: String = "androidtvremote"
    ): CertificateFilesResult {
        try {
            // 1. Generate RSA key pair
            val keyPair = generateKeyPair()

            // 2. Generate X.509 certificate
            val certificate = generateX509Certificate(
                keyPair.public,
                keyPair.private,
                certificateName
            )

            // 3. Save certificate to DER format
            val derPath = saveDERCertificate(context, certificate)

            // 4. Save PKCS#12 format
            val pkcs12Path = savePKCS12Certificate(
                context,
                certificate,
                keyPair.private,
                certificateName
            )

            return CertificateFilesResult(
                derPath = derPath,
                pkcs12Path = pkcs12Path,
                success = true
            )
        } catch (e: Exception) {
            return CertificateFilesResult(
                error = "Certificate generation failed: ${e.message}",
                success = false
            )
        }
    }

    private fun generateKeyPair(): KeyPair {
        // FIX 2: Let Android automatically resolve RSA key generation without hardcoding the provider link
        val keyGen = KeyPairGenerator.getInstance("RSA")
        keyGen.initialize(2048)
        return keyGen.generateKeyPair()
    }

    private fun generateX509Certificate(
        publicKey: PublicKey,
        privateKey: PrivateKey,
        commonName: String
    ): X509Certificate {
        val now = Date()
        val validityDays = 1825 // ~5 years
        val until = Date(now.time + validityDays * 24 * 60 * 60 * 1000L)

        // Build X.500 name
        val x500Name = X500Name("CN=$commonName")

        // Serial number
        val serialNumber = BigInteger.probablePrime(64, Random())

        // Create certificate builder
        val builder = JcaX509v3CertificateBuilder(
            x500Name,
            serialNumber,
            now,
            until,
            x500Name,
            publicKey
        )

        // Add basic constraints extension for self-signed cert
        builder.addExtension(
            Extension.basicConstraints,
            true,
            BasicConstraints(true)
        )

        // FIX 3: Remove .setProvider(...) so it uses our registered runtime fallback provider cleanly
        val contentSigner: ContentSigner = JcaContentSignerBuilder("SHA256withRSA")
            .build(privateKey)

        // Build certificate
        val certHolder = builder.build(contentSigner)

        // FIX 4: Use default instance converter provider context
        return JcaX509CertificateConverter()
            .getCertificate(certHolder)
    }

    private fun saveDERCertificate(
        context: Context,
        certificate: X509Certificate
    ): String {
        val fileName = "cert.der"
        val file = File(context.filesDir, fileName)

        FileOutputStream(file).use { fos ->
            fos.write(certificate.encoded)
        }

        return file.absolutePath
    }

    private fun savePKCS12Certificate(
        context: Context,
        certificate: X509Certificate,
        privateKey: PrivateKey,
        certificateName: String
    ): String {
        val fileName = "cert.p12"
        val file = File(context.filesDir, fileName)

        // FIX 5: Use regular instance resolution rather than forcing "BC" target
        val keyStore = KeyStore.getInstance("PKCS12")
        keyStore.load(null, null)

        // Add certificate and private key
        val chain = arrayOf<Certificate>(certificate)
        keyStore.setKeyEntry(
            certificateName,
            privateKey,
            CharArray(0), // Empty password for development
            chain
        )

        // Write to file
        FileOutputStream(file).use { fos ->
            keyStore.store(fos, CharArray(0))
        }

        return file.absolutePath
    }
}

data class CertificateFilesResult(
    val derPath: String = "",
    val pkcs12Path: String = "",
    val success: Boolean = false,
    val error: String = ""
)