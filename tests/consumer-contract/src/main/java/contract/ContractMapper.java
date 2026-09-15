package contract;

import org.mapstruct.Mapper;

@Mapper
public interface ContractMapper {

  Target map(Source source);

  record Source(String value) {}

  record Target(String value) {}
}
