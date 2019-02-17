contract PlasmaChain():
    def setup(operator: address, ethDecimalOffset: uint256, serializerAddr: address): modifying

NewPlasmaChain: event({PlasmaChainAddress: indexed(address), OperatorAddress: indexed(address), PlasmaChainName: bytes32, PlasmaChainIP: bytes32})

plasmaChainTemplate: public(address)
serializer: public(address)
plasmaChainNames: public(map(bytes32, address))
plasmaChainIPs: public(map(address, bytes32))

@public
def initializeRegistry(template: address, serializerAddr: address):
    assert self.plasmaChainTemplate == ZERO_ADDRESS
    assert template != ZERO_ADDRESS
    self.plasmaChainTemplate = template
    self.serializer = serializerAddr

@public
def createPlasmaChain(operator: address, plasmaChainName: bytes32, plasmaChainIP: bytes32) -> address:
    assert self.plasmaChainTemplate != ZERO_ADDRESS
    assert self.plasmaChainNames[plasmaChainName] == ZERO_ADDRESS
    plasmaChain: address = create_with_code_of(self.plasmaChainTemplate)
    PlasmaChain(plasmaChain).setup(operator, 0, self.serializer)
    self.plasmaChainNames[plasmaChainName] = operator
    self.plasmaChainIPs[operator] = plasmaChainIP
    log.NewPlasmaChain(plasmaChain, operator, plasmaChainName, plasmaChainIP)
    return plasmaChain

@public
def setIP (newIP: bytes32) -> bytes32:
    self.plasmaChainIPs[msg.sender] = newIP
    return newIP
