# Introducción

Este reporte se ha realizado sobre uno de los retos que podemos encontrar en la plataforma online [Damn Vulnerable DeFi](https://www.damnvulnerabledefi.xyz/) llamado [Unstoppable](https://www.damnvulnerabledefi.xyz/challenges/naive-receiver/). Las instruciones del reto se pueden consultar en la siguiente imagen:

![naive receiver instructions](https://github.com/user-attachments/assets/4f96c6d8-9714-41ee-93a5-80e0a1da29b8)

> [!NOTE]
> **Traducción:**
> Hay un fondo con 1000 WETH de saldo que ofrece préstamos flash. Tiene una comisión fija de 1 WETH. La _pool_ soporta meta-transacciones mediante la integración con un contrato forwarder sin permisos.
>
> Un usuario ha desplegado un contrato de muestra con 10 WETH de saldo. Parece que puede ejecutar préstamos flash de WETH.
>
> ¡Todos los fondos están en riesgo! Rescata todos los WETH del usuario y del pool, y deposítalos en la cuenta de recuperación designada.

Nuestro objetivo por tanto es investigar los contratos para obtener tanto los fondos del usuario que desplegó el contrato de prueba así como los fondos de la _pool_, un punto interesante es el hecho de que la pool soporta meta-transacciones, las cuales son transacciones en la blockchain donde el contrato o cuenta que originó la transacción no paga los gastos de gas de dicha transacción sino que lo hace un contrato intermedio que comprueba la firma de la transacción con el firmante. Esto puede ser interesante si el contrato de la _pool_ depende del contrato que produce las meta-transacciones, lo veremos según avancemos en nuestro análisis. Más información en el siguiente [enlace](https://ethereum.stackexchange.com/questions/63180/meta-transaction-explanation).

# Análisis de nuestro reto

Bien definidos los conceptos del reto podemos pasar a realizar el análisis de los contratos presentes.

## Contrato `NaiveReceiverPool.sol`

El constructor junto a las variables del contrato son las siguientes:

![constructor](https://github.com/user-attachments/assets/134e2184-02fb-4ce7-bd49-b0e04ea7a97e)

- `weth`: Contrato del token WETH de wrapper sobre ETH usando ERC20
- `trustedForwarder`: Dirección que designa al contrato de meta-transacciones (más abajo)
- `feeReceiver`: Dirección que va a recibir los _fees_ de los flash loans

Más abajo tenemos la función `withdraw`:

![withdraw function](https://github.com/user-attachments/assets/c6226bc5-9133-4fa5-a376-d6dd181c037c)

Esta función reduce el balance de la dirección que devuelve la función `_msgSender()` (ver más abajo), y transfiere la cantidad pasada por parámetro a la dirección pasada por parámetro.

Pasamos a la función de `_msgSender()`

![_msgSender function](https://github.com/user-attachments/assets/5952bbe0-ce38-4156-8d51-0fcb4ffbfd9d)

Esta función tiene bastante relevancia ya que si nos fijamos el resultado que retorna la función va a cambiar dependiendo de quien sea el `msg.sender` y la longitud de los datos de la transacción sea mayor de 20 bytes. Esto puede ser un punto de fallo crítico a la hora de vulnerar el contrato ya que podemos devolver la dirección que esté en los últimos 20 bytes del `msg.data`.

## Contrato `FlashLoanReceiver.sol`

La única función relevante de este contrato es `onFlashLoan()`:

![onFlashLoan() function](https://github.com/user-attachments/assets/b1b76a99-15ba-4077-a01c-208f24332119)

Esta función devolverá los tokens prestados en la flash loan y pagará el fee correspondiente de 1 WETH para que la flash loan no revierta.

## Contrato `BasicForwarder.sol`

El contrato BasicForwarder va a realizar la funcionalidad de las meta-transacciones implementando el EIP-712 del autor solady (_Contract for EIP-712 typed structured data hashing and signing._), vamos a destacar dos funciones:

![checkRequest function](https://github.com/user-attachments/assets/73cf9ef3-20f0-49fd-943b-403aa5191859)

La función checkRequest realizará comprobaciones sobre los parámetros de la request que queremos ejecutar como son el nonce o el deadline para no ejecutar request repetidas, un punto a destacar es la comprobación de la firma que se pasa al ejecutar la request y el firmante de la request los cuales tienen que coincidir para evitar firmar acciones por parte de otra dirección.

Por otro lado tenemos la función `execute()`:

![execute function](https://github.com/user-attachments/assets/f3ebc151-7d2e-4a2f-8388-ab839d60bd3a)

Esta función ejecutará primero la función `checkRequest()` mencionada anteriormente, para después inicializar las variables que se usarán en el `call` para ejecutar la request. Como vemos al crear el payload se concatena la dirección que hayamos puesto en el campo `from` que debe coincidir con el firmante de la request.
