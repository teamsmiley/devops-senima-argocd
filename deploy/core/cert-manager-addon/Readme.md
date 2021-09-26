# certificate issuer

secret가 업데이트되면 aws secret를 base64로 인코딩해서 yml파일에 업데이트해주면됨.

secret => eHvPBQSzJMiPmtexxxoJ89BB5dt0HDUdkzRI

echo -n 'eHvPBQSzJMiPmtexxxoJ89BB5dt0HDUdkzRI' | openssl base64

=> ZUh2UEJRU3pKTWlQbXxxxxKODlCQjVkdDBIRFVka3pSSQ==
