package org.wanja.book.quarkus;

import java.util.List;

import javax.transaction.Transactional;
import javax.ws.rs.Consumes;
import javax.ws.rs.GET;
import javax.ws.rs.POST;
import javax.ws.rs.PUT;
import javax.ws.rs.DELETE;
import javax.ws.rs.Path;
import javax.ws.rs.Produces;
import javax.ws.rs.WebApplicationException;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.Response;

import org.jboss.resteasy.annotations.jaxrs.PathParam;

import io.quarkus.panache.common.Sort;

@Path("/person")
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
public class PersonResource {
    
    @GET
    public List<Person> getAll() throws Exception {
        return Person.findAll(Sort.ascending("last_name")).list();
    }

    @GET
    @Path("{id}")
    public Person getPerson(@PathParam Long id) throws Exception {
        if( id == null ) throw new WebApplicationException("id must not be NULL");
        Person p = Person.findById(id);
        if( p == null ) throw new WebApplicationException("There is no person with id = " + id);
        return p;
    }

    @POST
    @Transactional
    public Response create(Person p) {
        if (p == null || p.id != null)
            throw new WebApplicationException("id != null");
        p.persist();
        return Response.ok(p).status(200).build();
    }

    @PUT
    @Transactional
    @Path("{id}")
    public Person update(@PathParam Long id, Person p) {
        Person entity = Person.findById(id);
        if (entity == null) {
            throw new WebApplicationException("Person with id of " + id + " does not exist.", 404);
        }
        if(p.salutation != null ) entity.salutation = p.salutation;
        if(p.firstName != null )  entity.firstName = p.firstName;
        if(p.lastName != null)    entity.lastName = p.lastName;
        return entity;
    }

    @DELETE
    @Path("{id}")
    @Transactional
    public Response delete(@PathParam Long id) {
        Person entity = Person.findById(id);
        if (entity == null) {
            throw new WebApplicationException("Person with id of " + id + " does not exist.", 404);
        }
        entity.delete();
        return Response.status(204).build();
    }

    @GET
    @Path("count")
    public Long count() {
        return Person.count();
    }

    @GET
    @Path("search/{salutation}")
    public List<Person> getPersonBySalutation(@PathParam String salutation) throws Exception {
        List<Person> lst = Person.find("salutation", salutation).list();
        return lst;
    }

}

