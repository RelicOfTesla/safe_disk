package sec_webdav

import (
	"crypto/rand"
	"crypto/rsa"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/pem"
	"fmt"
	"math/big"
	"net"
	"os"
	"path/filepath"
	"sync"
	"time"
)

var (
	tlsMu     sync.Mutex
	tlsConfig *tls.Config
	tlsCA     *x509.Certificate
	tlsCAKey  *rsa.PrivateKey
)

const (
	tlsDataDirName = "safe_disk"
	tlsSubDir      = "tls"
	// CA files — static, long-lived (10 years)
	tlsCAKeyFile  = "webdav-ca.key"
	tlsCACertFile = "webdav-ca.crt"
	// Leaf files — signed by CA, shorter validity (1 year)
	tlsLeafKeyFile  = "webdav-tls.key"
	tlsLeafCertFile = "webdav-tls.crt"
)

// tlsDataDir returns the platform-specific directory for persistent TLS material.
func tlsDataDir() (string, error) {
	var base string
	if userDir, err := os.UserConfigDir(); err == nil {
		base = userDir
	} else if homeDir, err := os.UserHomeDir(); err == nil {
		base = homeDir
	} else {
		return "", fmt.Errorf("webdav tls: cannot locate user directory")
	}
	dir := filepath.Join(base, tlsDataDirName, tlsSubDir)
	if err := os.MkdirAll(dir, 0700); err != nil {
		return "", fmt.Errorf("webdav tls: %w", err)
	}
	return dir, nil
}

// EnsureTLSConfig returns a persistent TLS configuration using a leaf
// certificate signed by a static CA. The CA is generated once and reused
// across all leaf certificates. Users only need to install the CA cert
// in their system trust store once.
// Set SAFE_DISK_WEBDAV_TLS_REGENERATE=1 to force regeneration.
func EnsureTLSConfig() (*tls.Config, error) {
	tlsMu.Lock()
	defer tlsMu.Unlock()
	if tlsConfig != nil {
		return tlsConfig, nil
	}
	dir, err := tlsDataDir()
	if err != nil {
		return nil, err
	}

	caKeyPath := filepath.Join(dir, tlsCAKeyFile)
	caCertPath := filepath.Join(dir, tlsCACertFile)
	leafKeyPath := filepath.Join(dir, tlsLeafKeyFile)
	leafCertPath := filepath.Join(dir, tlsLeafCertFile)

	if os.Getenv("SAFE_DISK_WEBDAV_TLS_REGENERATE") != "1" {
		if config, ok := loadLeafTLSFromDisk(leafKeyPath, leafCertPath); ok {
			tlsConfig = config
			loadCACertFromDisk(caCertPath)
			return config, nil
		}
	}

	caCert, caKey, err := ensureCA(caKeyPath, caCertPath)
	if err != nil {
		return nil, fmt.Errorf("ensure CA: %w", err)
	}
	tlsCA, tlsCAKey = caCert, caKey

	config, err := generateAndSaveLeafCert(leafKeyPath, leafCertPath, caCert, caKey)
	if err != nil {
		return nil, err
	}
	tlsConfig = config
	return config, nil
}

// ensureCA loads or generates a static CA key/cert pair.
func ensureCA(keyPath, certPath string) (*x509.Certificate, *rsa.PrivateKey, error) {
	if key, cert, ok := loadCAFromDisk(keyPath, certPath); ok {
		return cert, key, nil
	}
	return generateAndSaveCA(keyPath, certPath)
}

func loadCAFromDisk(keyPath, certPath string) (*rsa.PrivateKey, *x509.Certificate, bool) {
	keyPEM, err := os.ReadFile(keyPath)
	if err != nil {
		return nil, nil, false
	}
	certPEM, err := os.ReadFile(certPath)
	if err != nil {
		return nil, nil, false
	}
	keyBlock, _ := pem.Decode(keyPEM)
	if keyBlock == nil {
		return nil, nil, false
	}
	key, err := x509.ParsePKCS8PrivateKey(keyBlock.Bytes)
	if err != nil {
		return nil, nil, false
	}
	rsaKey, ok := key.(*rsa.PrivateKey)
	if !ok {
		return nil, nil, false
	}
	certBlock, _ := pem.Decode(certPEM)
	if certBlock == nil {
		return nil, nil, false
	}
	cert, err := x509.ParseCertificate(certBlock.Bytes)
	if err != nil {
		return nil, nil, false
	}
	return rsaKey, cert, true
}

func loadCACertFromDisk(certPath string) {
	if tlsCA != nil {
		return
	}
	data, err := os.ReadFile(certPath)
	if err != nil {
		return
	}
	block, _ := pem.Decode(data)
	if block == nil {
		return
	}
	cert, err := x509.ParseCertificate(block.Bytes)
	if err != nil {
		return
	}
	tlsCA = cert
}

func generateAndSaveCA(keyPath, certPath string) (*x509.Certificate, *rsa.PrivateKey, error) {
	key, err := rsa.GenerateKey(rand.Reader, 4096)
	if err != nil {
		return nil, nil, fmt.Errorf("generate CA key: %w", err)
	}
	template := &x509.Certificate{
		SerialNumber: big.NewInt(time.Now().UnixNano()),
		Subject: pkix.Name{
			CommonName:   "safe-disk-local-ca",
			Organization: []string{"Safe Disk Local CA"},
		},
		NotBefore:             time.Now().Add(-1 * time.Hour),
		NotAfter:              time.Now().Add(10 * 365 * 24 * time.Hour),
		KeyUsage:              x509.KeyUsageCertSign | x509.KeyUsageCRLSign,
		BasicConstraintsValid: true,
		IsCA:                  true,
		MaxPathLenZero:        true,
	}
	certDER, err := x509.CreateCertificate(rand.Reader, template, template, &key.PublicKey, key)
	if err != nil {
		return nil, nil, fmt.Errorf("create CA certificate: %w", err)
	}
	cert, err := x509.ParseCertificate(certDER)
	if err != nil {
		return nil, nil, fmt.Errorf("parse CA certificate: %w", err)
	}
	keyBytes, err := x509.MarshalPKCS8PrivateKey(key)
	if err != nil {
		return nil, nil, fmt.Errorf("marshal CA key: %w", err)
	}
	if err := os.WriteFile(keyPath, pem.EncodeToMemory(&pem.Block{
		Type:  "PRIVATE KEY",
		Bytes: keyBytes,
	}), 0600); err != nil {
		return nil, nil, fmt.Errorf("write CA key: %w", err)
	}
	if err := os.WriteFile(certPath, pem.EncodeToMemory(&pem.Block{
		Type:  "CERTIFICATE",
		Bytes: certDER,
	}), 0644); err != nil {
		return nil, nil, fmt.Errorf("write CA certificate: %w", err)
	}
	return cert, key, nil
}

func loadLeafTLSFromDisk(keyPath, certPath string) (*tls.Config, bool) {
	cert, err := tls.LoadX509KeyPair(certPath, keyPath)
	if err != nil {
		return nil, false
	}
	return &tls.Config{
		Certificates: []tls.Certificate{cert},
		MinVersion:   tls.VersionTLS12,
	}, true
}

func generateAndSaveLeafCert(keyPath, certPath string, caCert *x509.Certificate, caKey *rsa.PrivateKey) (*tls.Config, error) {
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		return nil, fmt.Errorf("generate leaf key: %w", err)
	}
	template := &x509.Certificate{
		SerialNumber: big.NewInt(time.Now().UnixNano()),
		Subject: pkix.Name{
			CommonName:   "127.0.0.1",
			Organization: []string{"Safe Disk WebDAV"},
		},
		NotBefore:             time.Now().Add(-1 * time.Hour),
		NotAfter:              time.Now().Add(365 * 24 * time.Hour),
		KeyUsage:              x509.KeyUsageKeyEncipherment | x509.KeyUsageDigitalSignature,
		ExtKeyUsage:           []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth},
		BasicConstraintsValid: true,
		DNSNames:              []string{"localhost"},
		IPAddresses:           []net.IP{net.ParseIP("127.0.0.1")},
	}
	certDER, err := x509.CreateCertificate(rand.Reader, template, caCert, &key.PublicKey, caKey)
	if err != nil {
		return nil, fmt.Errorf("create leaf certificate: %w", err)
	}
	keyBytes, err := x509.MarshalPKCS8PrivateKey(key)
	if err != nil {
		return nil, fmt.Errorf("marshal leaf key: %w", err)
	}
	if err := os.WriteFile(keyPath, pem.EncodeToMemory(&pem.Block{
		Type:  "PRIVATE KEY",
		Bytes: keyBytes,
	}), 0600); err != nil {
		return nil, fmt.Errorf("write leaf key: %w", err)
	}
	if err := os.WriteFile(certPath, pem.EncodeToMemory(&pem.Block{
		Type:  "CERTIFICATE",
		Bytes: certDER,
	}), 0644); err != nil {
		return nil, fmt.Errorf("write leaf certificate: %w", err)
	}
	return &tls.Config{
		Certificates: []tls.Certificate{{
			Certificate: [][]byte{certDER},
			PrivateKey:  key,
		}},
		MinVersion: tls.VersionTLS12,
	}, nil
}

// ExportCACertPEM returns the PEM-encoded CA certificate for installation
// in the system trust store. Installing the CA cert once trusts all leaf
// certificates signed by it.
func ExportCACertPEM() (string, error) {
	tlsMu.Lock()
	defer tlsMu.Unlock()
	dir, err := tlsDataDir()
	if err != nil {
		return "", err
	}
	caCertPath := filepath.Join(dir, tlsCACertFile)
	data, err := os.ReadFile(caCertPath)
	if err != nil {
		return "", fmt.Errorf("webdav CA cert not found (%s): ensure TLS has been initialized first; %w", caCertPath, err)
	}
	return string(data), nil
}

// ExportTLSCertPEM returns the PEM-encoded leaf certificate (signed by CA).
// Prefer ExportCACertPEM for system trust store installation.
func ExportTLSCertPEM() (string, error) {
	tlsMu.Lock()
	defer tlsMu.Unlock()
	dir, err := tlsDataDir()
	if err != nil {
		return "", err
	}
	certPath := filepath.Join(dir, tlsLeafCertFile)
	data, err := os.ReadFile(certPath)
	if err != nil {
		return "", fmt.Errorf("webdav TLS leaf cert not found (%s): %w", certPath, err)
	}
	return string(data), nil
}
